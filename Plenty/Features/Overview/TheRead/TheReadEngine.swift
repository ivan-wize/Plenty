//
//  TheReadEngine.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/TheRead/TheReadEngine.swift
//
//  Phase 7 (v2): retuned to speak v2 vocabulary. The hero concept is
//  no longer "spendable" — it's "what's left this month" derived from
//  `snapshot.monthlyBudgetRemaining`. The prompts, deterministic
//  templates, and snapshot summary all use the new framing.
//
//  Also new in P7:
//    • Pace bodies fold in `BurnRate.monthEndProjection` when the
//      month is at least five days in. The Read can now say "at this
//      pace, you'll end the month with about $400 to spare" instead
//      of just talking about per-day rates in the abstract.
//    • Deterministic classifier prefers monthEndProjection-flavored
//      paceWarning over generic pace messaging when the projection is
//      negative.
//
//  Backward-compat note: snapshot still populates v1 fields
//  (spendable, zone, pace) so the validator continues to recognize
//  amounts the AI mentions. The AI just no longer leans on those
//  words in its output.
//

import Foundation
import FoundationModels
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "the-read-engine")

// MARK: - Generables

@Generable
fileprivate struct ClassifierGeneration {
    @Guide(
        description: "The kind of read to surface for this snapshot. Pick exactly one.",
        .anyOf(["silence", "paceWarning", "paceTrend", "billReminder", "incomeReminder", "milestone"])
    )
    var kind: String
}

@Generable
fileprivate struct BodyGeneration {
    @Guide(description: "The Read body. A single calm sentence in second person, possession-leading. No exclamations, no em-dashes, no bullet points. Plain currency like $1,840.")
    var body: String

    @Guide(description: "If the body mentions any dollar amount, the most prominent one as a Decimal. Nil if no amount is mentioned.")
    var primaryAmount: Decimal?

    @Guide(description: "If the body mentions any specific date, the date in ISO 8601 format (YYYY-MM-DD). Nil if no date is mentioned.")
    var primaryDate: String?
}

@Generable
fileprivate struct WeeklyBodyGeneration {
    @Guide(description: "The Sunday Read body. 1-3 short sentences. Calm, second-person, possession-leading. No exclamations, no em-dashes, no bullet points.")
    var body: String

    @Guide(description: "If the body mentions any dollar amounts, the most prominent one. Nil if no amounts mentioned.")
    var primaryAmount: Decimal?
}

// MARK: - Engine

enum TheReadEngine {

    // MARK: - Daily Public Entry Point

    static func generate(snapshot: PlentySnapshot) async -> TheRead {
        if case .available = SystemLanguageModel.default.availability {
            if let aiRead = await aiGenerate(snapshot: snapshot) {
                return aiRead
            }
        }
        return deterministicGenerate(snapshot: snapshot)
    }

    // MARK: - Weekly Public Entry Point

    static func generateWeekly(snapshot: PlentySnapshot) async -> TheRead {
        if case .available = SystemLanguageModel.default.availability {
            if let aiRead = await aiGenerateWeekly(snapshot: snapshot) {
                return aiRead
            }
        }
        return deterministicGenerateWeekly(snapshot: snapshot)
    }

    // MARK: - Daily AI Path

    private static func aiGenerate(snapshot: PlentySnapshot) async -> TheRead? {
        guard let kind = await aiClassify(snapshot: snapshot) else { return nil }

        if kind == .silence {
            return TheRead(kind: .silence, body: "", generatedAt: .now, isAIGenerated: true)
        }

        for attempt in 1...2 {
            guard let generation = await aiGenerateBody(kind: kind, snapshot: snapshot) else {
                return nil
            }

            let claimedDate = generation.primaryDate.flatMap(Self.parseISO8601(_:))

            let validation = TheReadValidator.validate(
                claimedAmount: generation.primaryAmount,
                claimedDate: claimedDate,
                against: snapshot
            )

            if validation == .valid {
                return TheRead(kind: kind, body: generation.body, generatedAt: .now, isAIGenerated: true)
            }
            if attempt == 2 {
                logger.info("Read body failed validation twice, falling back: \(String(describing: validation))")
                return nil
            }
        }
        return nil
    }

    private static func aiClassify(snapshot: PlentySnapshot) async -> TheRead.Kind? {
        do {
            let session = LanguageModelSession(model: .default, instructions: classifierInstructions)
            let context = snapshotSummary(snapshot)
            let response = try await session.respond(
                to: "Snapshot:\n\(context)\n\nWhich kind?",
                generating: ClassifierGeneration.self
            )
            return TheRead.Kind(rawValue: response.content.kind) ?? .silence
        } catch {
            logger.error("Read classifier failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func aiGenerateBody(kind: TheRead.Kind, snapshot: PlentySnapshot) async -> BodyGeneration? {
        do {
            let session = LanguageModelSession(model: .default, instructions: bodyGeneratorInstructions(kind: kind))
            let context = snapshotSummary(snapshot)
            let response = try await session.respond(
                to: "Snapshot:\n\(context)\n\nWrite a single sentence for the \(kind.rawValue) read.",
                generating: BodyGeneration.self
            )
            return response.content
        } catch {
            logger.error("Read body gen failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Weekly AI Path

    private static func aiGenerateWeekly(snapshot: PlentySnapshot) async -> TheRead? {
        do {
            let session = LanguageModelSession(model: .default, instructions: weeklyInstructions)
            let context = snapshotSummary(snapshot)
            let response = try await session.respond(
                to: "Snapshot:\n\(context)\n\nWrite the Sunday Read.",
                generating: WeeklyBodyGeneration.self
            )

            let generation = response.content

            if let amount = generation.primaryAmount {
                let validation = TheReadValidator.validate(
                    claimedAmount: amount,
                    claimedDate: nil,
                    against: snapshot
                )
                if validation != .valid {
                    logger.info("Weekly read failed amount validation: \(String(describing: validation))")
                    return nil
                }
            }

            return TheRead(
                kind: .weekly,
                body: generation.body,
                generatedAt: .now,
                isAIGenerated: true
            )
        } catch {
            logger.error("Weekly read gen failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Daily Deterministic Path

    static func deterministicGenerate(snapshot: PlentySnapshot) -> TheRead {
        let kind = deterministicClassify(snapshot)
        if kind == .silence {
            return TheRead(kind: .silence, body: "", generatedAt: .now, isAIGenerated: false)
        }
        let body = deterministicBody(kind: kind, snapshot: snapshot)
        return TheRead(kind: kind, body: body, generatedAt: .now, isAIGenerated: false)
    }

    private static func deterministicClassify(_ snapshot: PlentySnapshot) -> TheRead.Kind {
        if snapshot.zone == .empty { return .silence }

        // v2 priority shifts: a negative monthlyBudgetRemaining is the
        // strongest signal. The pace warning still fires on burn-rate
        // overshoot but yields to the bigger story.
        if snapshot.monthlyBudgetIsNegative { return .paceWarning }
        if snapshot.pace == .over { return .paceWarning }
        if snapshot.billsRemaining > 0 { return .billReminder }

        if let next = snapshot.nextIncomeDate {
            let days = Calendar.current.dateComponents([.day], from: .now, to: next).day ?? 99
            if days <= 1 { return .incomeReminder }
        }

        if snapshot.pace == .onTrack,
           let sustainable = snapshot.sustainableDailyBurn,
           snapshot.smoothedDailyBurn < sustainable * Decimal(0.7),
           sustainable > 0 {
            return .paceTrend
        }

        if snapshot.actualSavingsThisMonth > 0 {
            return .milestone
        }
        return .silence
    }

    private static func deterministicBody(kind: TheRead.Kind, snapshot: PlentySnapshot) -> String {
        switch kind {
        case .silence, .weekly:
            return ""

        case .paceWarning:
            return paceWarningBody(snapshot: snapshot)

        case .paceTrend:
            return paceTrendBody(snapshot: snapshot)

        case .billReminder:
            let count = snapshot.billsTotalCount - snapshot.billsPaidCount
            let total = snapshot.billsRemaining.asCurrencyString()
            let plural = count == 1 ? "bill is" : "bills are"
            return "\(count) \(plural) still to pay this month totaling \(total)."

        case .incomeReminder:
            guard let next = snapshot.nextIncomeDate else { return "" }
            let cal = Calendar.current
            if cal.isDateInToday(next) { return "Your next paycheck arrives today." }
            if cal.isDateInTomorrow(next) { return "Your next paycheck arrives tomorrow." }
            let weekday = next.formatted(.dateTime.weekday(.wide))
            return "Your next paycheck arrives \(weekday)."

        case .milestone:
            let saved = snapshot.actualSavingsThisMonth.asCurrencyString()
            return "You've added \(saved) toward your savings this month."
        }
    }

    private static func paceWarningBody(snapshot: PlentySnapshot) -> String {
        let perDay = snapshot.smoothedDailyBurn.asCurrencyString()
        let sustainable = (snapshot.sustainableDailyBurn ?? 0).asCurrencyString()

        // If the month has matured enough for a projection, lead with it.
        if let projection = monthEndProjectionAmount(snapshot: snapshot) {
            if projection < 0 {
                let over = abs(projection).asCurrencyString()
                return "You're spending about \(perDay) a day; at this pace you'll be about \(over) over by month-end."
            }
        }

        return "You're spending about \(perDay) a day, above the \(sustainable) the rest of the month asks for."
    }

    private static func paceTrendBody(snapshot: PlentySnapshot) -> String {
        let perDay = snapshot.smoothedDailyBurn.asCurrencyString()

        if let projection = monthEndProjectionAmount(snapshot: snapshot), projection > 0 {
            let surplus = projection.asCurrencyString()
            return "You're tracking under at \(perDay) a day; at this pace you'll end the month with about \(surplus) left."
        }

        return "You're tracking under your usual pace at \(perDay) a day. The room is there if you want it."
    }

    /// Projected `monthlyBudgetRemaining` at month-end given current
    /// burn. Negative = projected shortfall, positive = projected
    /// surplus. Returns nil when the projection isn't reliable yet
    /// (early in the month, negligible burn signal, etc.) — same
    /// guards as `BurnRate.monthEndProjection`.
    private static func monthEndProjectionAmount(snapshot: PlentySnapshot) -> Decimal? {
        let calendar = Calendar.current
        let reference = Date.now
        let dayOfMonth = calendar.component(.day, from: reference)
        guard dayOfMonth >= 5 else { return nil }
        guard snapshot.smoothedDailyBurn > 1 else { return nil }
        guard let monthRange = calendar.range(of: .day, in: .month, for: reference) else {
            return nil
        }

        let daysInMonth = monthRange.count
        let daysRemaining = max(0, daysInMonth - dayOfMonth)
        let projectedAdditionalSpend = snapshot.smoothedDailyBurn * Decimal(daysRemaining)
        return snapshot.monthlyBudgetRemaining - projectedAdditionalSpend
    }

    // MARK: - Weekly Deterministic Path

    static func deterministicGenerateWeekly(snapshot: PlentySnapshot) -> TheRead {
        if snapshot.zone == .empty {
            return TheRead(kind: .weekly, body: "", generatedAt: .now, isAIGenerated: false)
        }

        var sentences: [String] = []

        // 1. Headline budget status.
        if snapshot.monthlyBudgetRemaining > 0 {
            let amount = snapshot.monthlyBudgetRemaining.asCurrencyString()
            sentences.append("You have \(amount) left for the rest of the month.")
        } else if snapshot.monthlyBudgetRemaining == 0 {
            sentences.append("You're at zero this month — everything's spoken for.")
        } else {
            let over = abs(snapshot.monthlyBudgetRemaining).asCurrencyString()
            sentences.append("You're \(over) over your budget this month.")
        }

        // 2. Bills situation.
        if snapshot.billsRemaining > 0 {
            let count = snapshot.billsTotalCount - snapshot.billsPaidCount
            let total = snapshot.billsRemaining.asCurrencyString()
            let plural = count == 1 ? "bill is" : "bills are"
            sentences.append("\(count) \(plural) still to pay totaling \(total).")
        } else if snapshot.billsTotalCount > 0 {
            sentences.append("Every bill for the month is squared away.")
        }

        // 3. Savings progress.
        if snapshot.actualSavingsThisMonth > 0 {
            let saved = snapshot.actualSavingsThisMonth.asCurrencyString()
            sentences.append("Saved \(saved) so far.")
        }

        return TheRead(
            kind: .weekly,
            body: sentences.joined(separator: " "),
            generatedAt: .now,
            isAIGenerated: false
        )
    }

    // MARK: - Snapshot Summary

    /// Renders the snapshot as a structured prompt context. v2 leads
    /// with monthlyBudgetRemaining and includes the calendar-derived
    /// `day` / `daysRemainingInMonth` fields so the model can reason
    /// about timing.
    private static func snapshotSummary(_ snapshot: PlentySnapshot) -> String {
        let cal = Calendar.current
        let now = Date.now
        let day = cal.component(.day, from: now)
        let monthLen = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let daysRemaining = max(0, monthLen - day)

        var lines: [String] = []
        lines.append("monthlyBudgetRemaining: \(snapshot.monthlyBudgetRemaining)")
        lines.append("confirmedIncome: \(snapshot.confirmedIncome)")
        lines.append("expectedIncomeRemaining: \(snapshot.expectedIncomeRemaining)")
        lines.append("billsTotal: \(snapshot.billsTotal) (\(snapshot.billsTotalCount) bills, \(snapshot.billsTotalCount - snapshot.billsPaidCount) unpaid)")
        lines.append("billsRemaining: \(snapshot.billsRemaining)")
        lines.append("expensesThisMonth: \(snapshot.expensesThisMonth)")
        lines.append("plannedSavingsRemaining: \(snapshot.plannedSavingsRemaining)")
        lines.append("actualSavingsThisMonth: \(snapshot.actualSavingsThisMonth)")
        lines.append("smoothedDailyBurn: \(snapshot.smoothedDailyBurn)")
        if let s = snapshot.sustainableDailyBurn {
            lines.append("sustainableDailyBurn: \(s)")
        }
        if let projection = monthEndProjectionAmount(snapshot: snapshot) {
            lines.append("monthEndProjection: \(projection)")
        }
        lines.append("day: \(day)")
        lines.append("daysRemainingInMonth: \(daysRemaining)")
        if let next = snapshot.nextIncomeDate {
            lines.append("nextIncomeDate: \(Self.iso8601DateFormatter.string(from: next))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Prompts

    fileprivate static let classifierInstructions = """
    You are a classifier for "The Read", a single calm sentence shown beneath \
    Plenty's Overview hero number. Pick exactly one of these kinds:

    • silence       — Nothing distinctive to say. Use this generously.
    • paceWarning   — Spending pace is above sustainable, OR monthlyBudgetRemaining \
    is negative. The user is overspending.
    • paceTrend     — Spending pace is meaningfully below sustainable; positive note.
    • billReminder  — Unpaid bills this month deserve a heads-up.
    • incomeReminder — A paycheck is arriving in the next day or two.
    • milestone     — Positive savings progress worth acknowledging.

    Rules:
    • If the user has no data at all, pick silence.
    • If monthlyBudgetRemaining is negative, prefer paceWarning.
    • If pace is over (smoothedDailyBurn > sustainableDailyBurn), prefer paceWarning.
    • Otherwise pick the most relevant single kind.
    • When in doubt, pick silence. Restraint matters more than coverage.

    Output only the kind value.
    """

    fileprivate static func bodyGeneratorInstructions(kind: TheRead.Kind) -> String {
        let voiceRules = """
        Voice rules:
        • One sentence. No exclamations.
        • Second person ("you have", "your bills").
        • Possession-leading where natural ("you have $1,840 left" not "$1,840 is left").
        • No em-dashes, no bullet points, no marketing language, no emojis.
        • Plain currency like $1,840 (no decimals on whole dollars).
        • Calm and direct. Calm matters more than clever.

        If you mention a dollar amount, set primaryAmount to that exact value (Decimal).
        If you mention a specific date, set primaryDate to ISO 8601 (YYYY-MM-DD).
        """

        switch kind {
        case .paceWarning:
            return """
            Write a paceWarning sentence for The Read. Speak about the user's spending \
            pace and what it means for the rest of the month. If a monthEndProjection \
            value is provided in the snapshot and it's negative, lead with the projected \
            month-end shortfall. Otherwise speak about the per-day rate compared to \
            sustainable.

            Example: "You're spending about $58 a day; at this pace you'll be about $200 \
            over by month-end."

            \(voiceRules)
            """

        case .paceTrend:
            return """
            Write a paceTrend sentence for The Read. Speak calmly about the user being \
            under their usual pace. If a monthEndProjection value is provided and it's \
            positive, mention the projected month-end surplus. Otherwise speak about the \
            per-day rate.

            Example: "You're tracking under at $28 a day; at this pace you'll end the \
            month with about $400 left."

            \(voiceRules)
            """

        case .billReminder:
            return """
            Write a billReminder sentence for The Read. Mention the count of unpaid bills \
            and their total.

            Example: "Three bills are still unpaid this month, totaling $1,240."

            \(voiceRules)
            """

        case .incomeReminder:
            return """
            Write an incomeReminder sentence for The Read. Mention when the next paycheck \
            arrives. Use "today" or "tomorrow" when applicable, otherwise the weekday.

            Example: "Your next paycheck arrives Friday."

            \(voiceRules)
            """

        case .milestone:
            return """
            Write a milestone sentence for The Read. Acknowledge savings progress this \
            month with the actual amount.

            Example: "You've added $300 toward your savings this month."

            \(voiceRules)
            """

        case .silence, .weekly:
            return voiceRules
        }
    }

    fileprivate static let weeklyInstructions = """
    You are writing the Sunday Read, a calm weekly digest delivered as a notification \
    on Sunday mornings. Compose 1-3 short sentences that summarize where the user \
    stands financially right now.

    Voice:
    • Second person ("you have", "your bills", "your savings")
    • Possession-leading ("you have $1,840 left" not "$1,840 is available")
    • Calm and direct, no exclamations
    • No em-dashes, no bullet points, no emojis, no marketing language
    • Plain currency like "$1,840"
    • Each sentence complete and self-contained
    • Total length 1-3 sentences, never more

    Content priorities (in order):
    1. Monthly budget status — how much is left this month, or whether the user is over.
       Use monthlyBudgetRemaining as the headline number.
    2. Bills situation — count and total of unpaid bills, or "all paid"
    3. Savings progress — amount saved this month, if any

    Skip anything that doesn't apply. If the user has no meaningful financial activity, \
    return an empty body.

    If you mention a dollar amount, set primaryAmount to the most prominent one for \
    validation.
    """

    // MARK: - Helpers

    private static func parseISO8601(_ string: String) -> Date? {
        Self.iso8601DateFormatter.date(from: string)
    }

    private static let iso8601DateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
}

// MARK: - Decimal helper

private extension Decimal {
    func asCurrencyString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
