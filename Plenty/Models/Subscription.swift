//
//  Subscription.swift
//  Plenty
//
//  Target path: Plenty/Models/Subscription.swift
//
//  NEW in Plenty. Represents a recurring charge the user tracks.
//
//  Lifecycle:
//    1. SubscriptionDetector (Phase 7) runs against Transaction history.
//       When it finds a merchant with 3+ charges at consistent cadence,
//       it creates a Subscription with `state = .suggested`.
//    2. User confirms the suggestion on the Subscriptions screen, which
//       flips state to .confirmed.
//    3. User may later mark it `toCancel`, which triggers an EventKit
//       reminder before the next renewal (Phase 7).
//
//  User may also add a subscription manually; it enters directly at
//  .confirmed. User may dismiss a suggestion, which moves it to
//  .dismissed and hides it from the suggestions list going forward.
//
//  Storage shape mirrors the other @Models: positive-magnitude amounts,
//  raw-string enums for CloudKit, no .unique attributes, default values
//  at declaration site.
//

import Foundation
import SwiftData

@Model
final class Subscription {

    // MARK: - Identity

    var id: UUID = UUID()

    /// Canonical merchant name after normalization ("Netflix", not
    /// "NETFLIX.COM 866-579-7172"). Populated by AISubscriptionNormalizer
    /// in Phase 7; the manual-add flow takes the string verbatim from
    /// the user.
    var merchantName: String = ""

    /// Raw merchant string as it appears on transactions, used to match
    /// future charges. May differ from `merchantName` (one canonical
    /// merchant, many raw strings).
    var rawMerchantPattern: String = ""

    // MARK: - Cost

    /// Typical charge amount. Detection tolerates ±5% variance per PRD §9.5;
    /// this is the median of recent charges.
    var typicalAmount: Decimal = 0

    /// Amortized monthly cost. For annual subscriptions, this is
    /// `typicalAmount / 12`. For weekly, `typicalAmount * 52 / 12`. Stored
    /// so the "Subscriptions cost you $X a year" summary and the sort
    /// order do not recompute on every read.
    var monthlyCost: Decimal = 0

    /// Sum of every charge we've seen for this subscription. Informational.
    var totalPaidLifetime: Decimal = 0

    // MARK: - Cadence

    /// Detection window per PRD §9.5: weekly, monthly, or annual. Quarterly
    /// and other cadences are tracked as the closest match plus a note.
    /// Stored as raw string for CloudKit.
    var cadenceRaw: String = Cadence.monthly.rawValue

    /// Next expected charge date. Computed from the last seen charge
    /// plus the cadence.
    var nextChargeDate: Date?

    /// Most recent charge date we've matched to this subscription.
    var lastChargeDate: Date?

    // MARK: - State

    /// User-controlled state. Stored as raw string for CloudKit.
    var stateRaw: String = State.suggested.rawValue

    /// Whether the user has marked this subscription for cancellation.
    /// When true, EventKit reminder fires the day before nextChargeDate.
    var isMarkedToCancel: Bool = false

    // MARK: - Sharing (V1.1 hook)

    /// Reserved for V1.1 household sharing. Always false in V1.0. The
    /// field exists so V1.1 ships without a schema migration.
    var isShared: Bool = false

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Init

    init(
        merchantName: String,
        rawMerchantPattern: String,
        typicalAmount: Decimal,
        cadence: Cadence,
        nextChargeDate: Date? = nil,
        lastChargeDate: Date? = nil,
        state: State = .suggested
    ) {
        self.id = UUID()
        self.merchantName = merchantName
        self.rawMerchantPattern = rawMerchantPattern
        self.typicalAmount = typicalAmount
        self.monthlyCost = Subscription.amortizeMonthly(typicalAmount, cadence: cadence)
        self.cadenceRaw = cadence.rawValue
        self.nextChargeDate = nextChargeDate
        self.lastChargeDate = lastChargeDate
        self.stateRaw = state.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Computed

    var cadence: Cadence {
        get { Cadence(rawValue: cadenceRaw) ?? .monthly }
        set { cadenceRaw = newValue.rawValue }
    }

    var state: State {
        get { State(rawValue: stateRaw) ?? .suggested }
        set { stateRaw = newValue.rawValue }
    }

    /// Annualized cost for the "Subscriptions cost you $X a year" summary.
    var annualCost: Decimal { monthlyCost * 12 }

    // MARK: - Mutators

    /// Apply a newly-observed charge to this subscription. Updates
    /// lastChargeDate, totalPaidLifetime, and nextChargeDate.
    func applyCharge(amount: Decimal, date: Date, calendar: Calendar = .current) {
        totalPaidLifetime += amount
        lastChargeDate = date
        nextChargeDate = cadence.advance(date, calendar: calendar)
        updatedAt = .now
    }

    func confirm() {
        state = .confirmed
        updatedAt = .now
    }

    func dismiss() {
        state = .dismissed
        updatedAt = .now
    }

    func markToCancel() {
        isMarkedToCancel = true
        updatedAt = .now
    }

    func unmarkToCancel() {
        isMarkedToCancel = false
        updatedAt = .now
    }

    // MARK: - Amortization

    private static func amortizeMonthly(_ amount: Decimal, cadence: Cadence) -> Decimal {
        let factor: Decimal
        switch cadence {
        case .weekly:  factor = 52 / 12
        case .monthly: factor = 1
        case .annual:  factor = Decimal(1) / Decimal(12)
        }
        var result = amount * factor
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &result, 2, .bankers)
        return rounded
    }
}

// MARK: - Cadence

extension Subscription {

    enum Cadence: String, Codable, CaseIterable, Identifiable, Sendable {
        case weekly
        case monthly
        case annual

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .weekly:  return "Weekly"
            case .monthly: return "Monthly"
            case .annual:  return "Annual"
            }
        }

        /// PRD §9.5 detection windows, expressed in days.
        var detectionWindow: ClosedRange<Int> {
            switch self {
            case .weekly:  return 6...8
            case .monthly: return 28...32
            case .annual:  return 350...380
            }
        }

        func advance(_ date: Date, calendar: Calendar = .current) -> Date? {
            switch self {
            case .weekly:  return calendar.date(byAdding: .day, value: 7, to: date)
            case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
            case .annual:  return calendar.date(byAdding: .year, value: 1, to: date)
            }
        }
    }
}

// MARK: - State

extension Subscription {

    enum State: String, Codable, CaseIterable, Identifiable, Sendable {

        /// Detector found it. User hasn't acted on the suggestion yet.
        case suggested

        /// User confirmed this is a recurring subscription (or added
        /// it manually).
        case confirmed

        /// User said "this isn't actually a subscription." Hidden from
        /// suggestions list going forward; detector won't re-suggest.
        case dismissed

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .suggested: return "Suggested"
            case .confirmed: return "Tracked"
            case .dismissed: return "Dismissed"
            }
        }
    }
}
