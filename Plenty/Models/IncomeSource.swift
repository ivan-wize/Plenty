//
//  IncomeSource.swift
//  Plenty
//
//  Target path: Plenty/Models/IncomeSource.swift
//
//  A template describing a recurring income stream. The user names it
//  ("Paycheck," "Rental income"), sets an expected amount, picks a
//  frequency, and optionally designates a destination cash account.
//
//  IncomeEntryGenerator turns this template into concrete Transaction
//  records of kind .income with status .expected for the current month.
//  Users confirm or skip each entry as paychecks actually arrive.
//
//  Replaces the prior IncomeSource. One change: `init` now takes
//  `IncomeSource.Frequency` (the cohesive type) instead of
//  `RecurringRule.Frequency`. AddIncomeSheet was already passing
//  `IncomeSource.Frequency`; the prior signature was a hidden type
//  mismatch.
//

import Foundation
import SwiftData

@Model
final class IncomeSource {

    // MARK: - Identity

    var id: UUID = UUID()

    /// Display name.
    var name: String = ""

    /// Expected amount per occurrence.
    var expectedAmount: Decimal = 0

    /// Recurrence policy. Stored as a raw string for CloudKit.
    /// Always one of the four IncomeSource.Frequency raw values:
    /// "weekly" | "biweekly" | "semimonthly" | "monthly".
    var frequencyRaw: String = IncomeSource.Frequency.biweekly.rawValue

    /// Day of the month for monthly/semimonthly sources. 1-31.
    /// For monthly: the day of the month. For semimonthly: the first day.
    var dayOfMonth: Int = 1

    /// Secondary day for semimonthly (e.g. 15 for "1st and 15th").
    var secondDayOfMonth: Int?

    /// Weekday for weekly/biweekly (0=Sunday, 6=Saturday).
    var weekday: Int = 5  // default Friday

    /// Anchor date for biweekly parity.
    var biweeklyAnchor: Date?

    /// Whether the source is currently active. Inactive sources generate
    /// no new expected entries but preserve their history.
    var isActive: Bool = false

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Init

    init(
        name: String,
        expectedAmount: Decimal,
        frequency: Frequency,
        dayOfMonth: Int = 1,
        secondDayOfMonth: Int? = nil,
        weekday: Int = 5,
        biweeklyAnchor: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.expectedAmount = expectedAmount
        self.frequencyRaw = frequency.rawValue
        self.dayOfMonth = dayOfMonth
        self.secondDayOfMonth = secondDayOfMonth
        self.weekday = weekday
        self.biweeklyAnchor = biweeklyAnchor
        self.isActive = isActive
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Frequency

    /// IncomeSource only supports the four sub-monthly cadences. Quarterly
    /// and annually are RecurringRule features that don't apply to
    /// paychecks in practice.
    enum Frequency: String, Codable, CaseIterable, Identifiable, Sendable {
        case weekly
        case biweekly
        case semimonthly
        case monthly

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .weekly:      return "Weekly"
            case .biweekly:    return "Biweekly"
            case .semimonthly: return "Twice a Month"
            case .monthly:     return "Monthly"
            }
        }

        var asRecurringRuleFrequency: RecurringRule.Frequency {
            switch self {
            case .weekly:      return .weekly
            case .biweekly:    return .biweekly
            case .semimonthly: return .semimonthly
            case .monthly:     return .monthly
            }
        }
    }

    // MARK: - Computed

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .biweekly }
        set { frequencyRaw = newValue.rawValue }
    }
}
