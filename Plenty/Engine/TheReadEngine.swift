//
//  TheReadEngine.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/TheRead/TheReadEngine.swift
//
//  Phase 4: generates daily TheRead via 2-stage AI (classifier + body)
//           with deterministic templates as fallback.
//  Phase 7 update: + generateWeekly() that produces the Sunday Read.
//           Body is up to 3 sentences and synthesizes the week's
//           highlights instead of one observation.
//
//  Both daily and weekly share validator, fallback patterns, and the
//  same restraint policy: when there's nothing meaningful to say, say
//  nothing (silence kind).
//

import Foundation
import FoundationModels

enum TheReadEngine {

    // MARK: - Daily (Phase 4) — Public Entry Point

    static func generate(snapshot: PlentySnapshot) async -> TheRead {
        if case .available = SystemLanguageModel.default.availability {
            if let aiRead = await aiGenerate(snapshot: snapshot) {
                return aiRead
            }
        }
        return deterministicGenerate(snapshot: snapshot)
    }

    // MARK: - Weekly (Phase 7) — Public Entry Point

    /// Generate the Sunday Read. Same two-stage pattern as daily, but
    /// produces a longer-form body (1-3 sentences) suited for a
    /// notification.
    static func generateWeekly(snapshot: PlentySnapshot) async -> TheRead {
        if case .available = SystemLanguageModel.default.availability {
            if let aiRead = await aiGenerateWeekly(snapshot: snapshot) {
                return aiRead
            }
        }
        return deterministicGenerateWeekly(snapshot: snapshot)
    }

    // MARK: - Daily AI Path (unchanged from Phase 4)

    private static func aiGenerate(snapshot: PlentySnapshot) async -> TheRead? {
        guard let kind = await aiClassify(snapshot: snapshot) else {
            return nil
        }

        if kind == .silence {
            return TheRead(kind: .silence, body: "", generatedAt: .now, isAIGenerated: true)
        }

        for attempt in 1...2 {
            guard let generation = await aiGenerateBody(kind: kind, snapshot: snapshot) else {
                return nil
            }

            let validation = TheReadValidator.validate(
                claimedAmount: generation.primaryAmount,
                claimedDate: generation.primaryDate,
                against: snapshot
            )

            if validation == .valid {
                return TheRead(kind: kind, body: generation.body, generatedAt: .now, isAIGenerated: true)
            }
            if attempt == 2 { return nil }
        }
        return nil
    }

    @Generable
    private struct ClassifierOutput {
        @Guide(.anyOf(["silence", "paceWarning", "paceTrend", "billReminder", "incomeReminder", "milestone"]))
        var kind: String
    }

    private static func aiClassify(snapshot: PlentySnapshot) async -> TheRead.Kind? {
        do {
            let session = LanguageModelSession(model: .default, instructions: classifierInstructions)
            let context = snapshotSummary(snapshot)
            let response = try await session.respond(
                to: "Snapshot:\n\(context)\n\nReturn the most appropriate Read kind.",
                generating: ClassifierOutput.self
            )
            return TheRead.Kind(rawValue: response.content.kind)
        } catch {
            return nil
        }
    }

    @Generable
    private struct BodyGeneration {
        @Guide(description: "The Read sentence shown to the user. One short sentence, second-person, possession-leading, no exclamations, no em-dashes.")
        var body: String

        @Guide(description: "If the body mentions a dollar amount, the exact value as Decimal. Nil if no amount is mentioned.")
        var primaryAmount: Decimal?

        @Guide(description: "If the body references a specific date, that date. Nil if no date is mentioned.")
        var primaryDate: Date?
    }

    private static func aiGenerateBody(
        kind: TheRead.Kind,
        snapshot: PlentySnapshot
    ) async -> BodyGeneration? {
        do {
            let session = LanguageModelSession(model: .default, instructions: bodyGeneratorInstructions(kind: kind))
            let context = snapshotSummary(snapshot)
            let response = try await session.respond(
                to: "Snapshot:\n\(context)\n\nWrite the Read.",
                generating: BodyGeneration.self
            )
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Weekly AI Path (Phase 7)

    @Generable
    private struct WeeklyBodyGeneration {
        @Guide(description: "The Sunday Read body. 1-3 short sentences. Calm, second-person, possession-leading. No exclamations, no em-dashes, no bullet points.")
        var body: String

        @Guide(description: "If the body mentions any dollar amounts, the most prominent one. Nil if no amounts mentioned.")
        var primaryAmount: Decimal?
    }

    private static func aiGenerateWeekly(snapshot: PlentySnapshot) async -> TheRead? {
        do {
            let session = LanguageModelSession(model: .default, instructions: weeklyInstructions)
            let context = snapshotSummary(snapshot)
            let response = try await session.respond(
                to: "Snapshot:\n\(context)\n\nWrite the Sunday Read.",
                generating: WeeklyBodyGeneration.self
            )

            let generation = response.content

            // Weekly skips date validation (no specific dates in 1-3
            // sentence summaries) but still validates amounts when present.
            if let amount = generation.primaryAmount {
                let validation = TheReadValidator.validate(
                    claimedAmount: amount,
                    claimedDate: nil,
                    against: snapshot
                )
                if validation != .valid { return nil }
            }

            return TheRead(
                kind: .weekly,
                body: generation.body,
                generatedAt: .now,
                isAIGenerated: true
            )
        } catch {
            return nil
        }
    }

    // MARK: - Daily Deterministic Path (unchanged from Phase 4)

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
        if snapshot.actualSavingsThisMonth > 0 { return .milestone }
        return .silence
    }

    private static func deterministicBody(kind: TheRead.Kind, snapshot: PlentySnapshot) -> String {
        switch kind {
        case .silence, .weekly:
            return ""
        case .paceWarning:
            let pacePerDay = snapshot.smoothedDailyBurn.asCurrencyString()
            let sustainable = (snapshot.sustainableDailyBurn ?? 0).asCurrencyString()
            return "Your spending sits at \(pacePerDay) a day. To finish the month with margin, \(sustainable) a day is the line."
        case .paceTrend:
            let pacePerDay = snapshot.smoothedDailyBurn.asCurrencyString()
            return "You're tracking under your usual pace at \(pacePerDay) a day. The room is there if you want it."
        case .billReminder:
            let count = snapshot.billsTotalCount - snapshot.billsPaidCount
            let total = snapshot.billsRemaining.asCurrencyString()
            if count == 1 { return "One bill is still unpaid this month, totaling \(total)." }
            return "\(count) bills are still unpaid this month, totaling \(total)."
        case .incomeReminder:
            guard let next = snapshot.nextIncomeDate else {
                return "Your next paycheck is on its way."
            }
            let weekday = Self.weekdayFormatter.string(from: next)
            return "Your next paycheck arrives \(weekday)."
        case .milestone:
            let saved = snapshot.actualSavingsThisMonth.asCurrencyString()
            return "You've added \(saved) toward your savings this month."
        }
    }

    // MARK: - Weekly Deterministic Path (Phase 7)

    static func deterministicGenerateWeekly(snapshot: PlentySnapshot) -> TheRead {
        let body = weeklyDeterministicBody(snapshot: snapshot)
        if body.isEmpty {
            return TheRead(kind: .silence, body: "", generatedAt: .now, isAIGenerated: false)
        }
        return TheRead(kind: .weekly, body: body, generatedAt: .now, isAIGenerated: false)
    }

    /// Compose 1-3 sentences from the most relevant facts in the
    /// snapshot. Order: spendable status, bills situation, savings note.
    private static func weeklyDeterministicBody(snapshot: PlentySnapshot) -> String {
        if snapshot.zone == .empty { return "" }

        var sentences: [String] = []

        // Sentence 1: spendable status.
        let spendable = snapshot.spendable.asCurrencyString()
        if snapshot.spendable < 0 {
            let over = (snapshot.spendable < 0 ? -snapshot.spendable : snapshot.spendable).asCurrencyString()
            sentences.append("You're \(over) past your margin this month.")
        } else {
            sentences.append("You have \(spendable) spendable through the rest of the month.")
        }

        // Sentence 2: bills situation, if relevant.
        if snapshot.billsRemaining > 0 {
            let count = snapshot.billsTotalCount - snapshot.billsPaidCount
            let total = snapshot.billsRemaining.asCurrencyString()
            let plural = count == 1 ? "bill is" : "bills are"
            sentences.append("\(count) \(plural) still to pay totaling \(total).")
        } else if snapshot.billsTotalCount > 0 {
            sentences.append("Every bill for the month is squared away.")
        }

        // Sentence 3: savings progress, if any.
        if snapshot.actualSavingsThisMonth > 0 {
            let saved = snapshot.actualSavingsThisMonth.asCurrencyString()
            sentences.append("Saved \(saved) so far.")
        }

        return sentences.joined(separator: " ")
    }

    // MARK: - Snapshot Summary

    private static func snapshotSummary(_ snapshot: PlentySnapshot) -> String {
        var lines: [String] = []
        lines.append("spendable: \(snapshot.spendable)")
        lines.append("cashOnHand: \(snapshot.cashOnHand)")
        lines.append("billsRemaining: \(snapshot.billsRemaining) (\(snapshot.billsTotalCount - snapshot.billsPaidCount) unpaid)")
        lines.append("statementDueBeforeNextIncome: \(snapshot.statementDueBeforeNextIncome)")
        lines.append("plannedSavingsRemaining: \(snapshot.plannedSavingsRemaining)")
        lines.append("expensesThisMonth: \(snapshot.expensesThisMonth)")
        lines.append("smoothedDailyBurn: \(snapshot.smoothedDailyBurn)")
        if let s = snapshot.sustainableDailyBurn {
            lines.append("sustainableDailyBurn: \(s)")
        }
        lines.append("pace: \(snapshot.pace)")
        lines.append("zone: \(snapshot.zone)")
        if let next = snapshot.nextIncomeDate {
            let formatter = ISO8601DateFormatter()
            lines.append("nextIncomeDate: \(formatter.string(from: next))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Prompts (mirror Resources/TheReadPrompt.md)

    private static let classifierInstructions = """
    You are a classifier for "The Read", a single contextual sentence shown
    beneath a budget hero number. Pick exactly one of these kinds:

    • silence       — Nothing distinctive to say. Use this generously.
    • paceWarning   — Burn rate is above sustainable; the user is overspending.
    • paceTrend     — Burn rate is meaningfully below sustainable; positive note.
    • billReminder  — Unpaid bills this month deserve a heads-up.
    • incomeReminder — A paycheck is arriving in the next day or two.
    • milestone     — Positive savings progress worth acknowledging.

    Rules:
    • If the user has no data (zone=empty), pick silence.
    • If pace is over, prefer paceWarning over other kinds.
    • Otherwise pick the most relevant single kind.
    • When in doubt, pick silence. Restraint matters more than coverage.

    Output only the kind value.
    """

    private static func bodyGeneratorInstructions(kind: TheRead.Kind) -> String {
        let voiceRules = """
        Voice:
        • Second person ("you have", "your bills", "your paycheck")
        • Possession-leading ("you have $1,840" not "$1,840 is available")
        • Calm and direct, no exclamations
        • No em-dashes anywhere
        • No marketing language, no excitement, no emojis
        • One sentence, complete and self-contained
        • Use plain currency formatting like "$1,840" or "$45 a day"
        • If you mention a dollar amount, set primaryAmount to that exact value
        • If you mention a specific date, set primaryDate to that date
        """

        let kindGuidance: String
        switch kind {
        case .silence, .weekly:
            kindGuidance = "Return an empty body."
        case .paceWarning:
            kindGuidance = "Note that spending is above sustainable. State the per-day burn and the sustainable per-day rate. No moral judgment, no panic."
        case .paceTrend:
            kindGuidance = "Note that spending is comfortably below sustainable. Mention the per-day burn. Frame as room available, not a goal."
        case .billReminder:
            kindGuidance = "Note unpaid bills. State the count and total. Do not mention which bills."
        case .incomeReminder:
            kindGuidance = "Note that a paycheck arrives soon. State the day of the week."
        case .milestone:
            kindGuidance = "Note positive savings progress this month. State the amount saved."
        }

        return """
        You write "The Read", a single contextual sentence beneath a budget
        hero number. The user asked for a \(kind.rawValue) Read.

        \(kindGuidance)

        \(voiceRules)
        """
    }

    private static let weeklyInstructions = """
    You are writing the Sunday Read, a calm weekly digest delivered as a
    notification on Sunday mornings. Compose 1-3 short sentences that
    summarize where the user stands financially right now.

    Voice:
    • Second person ("you have", "your bills", "your savings")
    • Possession-leading ("you have $1,840" not "$1,840 is available")
    • Calm and direct, no exclamations
    • No em-dashes, no bullet points, no emojis, no marketing language
    • Plain currency like "$1,840"
    • Each sentence complete and self-contained
    • Total length 1-3 sentences, never more

    Content priorities (in order):
    1. Spendable status — how much is available, or whether the user is over
    2. Bills situation — count and total of unpaid bills, or "all paid"
    3. Savings progress — amount saved this month, if any

    Skip anything that doesn't apply. If the user has no meaningful financial
    activity (zone=empty), return an empty body.

    If you mention a dollar amount, set primaryAmount to the most prominent
    one for validation.
    """

    // MARK: - Formatters

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}

// MARK: - Decimal Helpers

private extension Decimal {
    func asCurrencyString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
