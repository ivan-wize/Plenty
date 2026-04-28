//
//  IncomeSource.swift
//  Plenty
//
//  Target path: Plenty/Models/IncomeSource.swift
//
//  Phase 0 (v2): adds `rolloverEnabled` to control whether this template
//  auto-materializes entries in future months.
//
//  A template describing a recurring income stream. The user names it
//  ("Paycheck," "Rental income"), sets an expected amount, picks a
//  frequency, and optionally designates a destination cash account.
//
//  IncomeEntryGenerator turns this template into concrete Transaction
//  records of kind .income with status .expected for the current month.
//  Users confirm or skip each entry as paychecks actually arrive.
//
//  v2 change — `rolloverEnabled` (default true):
//    • true  → IncomeEntryGenerator auto-materializes entries each
//              month (current behavior).
//    • false → the template is dormant; the user opts in per-month via
//              "Copy from previous month" on the Income tab.
//
//  This lets users keep a template for unstable income (freelance, gig)
//  without the forecast cluttering their projection line.
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

    /// v2 — whether this template auto-materializes entries when a new
    /// month begins. Default true. When false, the user must use
    /// "Copy from previous month" on the Income tab to bring entries
    /// into the current month manually.
    ///
    /// Optional in storage so existing records (none, since v1
    /// unreleased) and CloudKit syncs without the field present default
    /// to true.
    var rolloverEnabled: Bool = true

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
        isActive: Bool = true,
        rolloverEnabled: Bool = true
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
        self.rolloverEnabled = rolloverEnabled
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
            case .biweekly:    return "Every two weeks"
            case .semimonthly: return "Twice a month"
            case .monthly:     return "Monthly"
            }
        }
    }

    /// Type-safe accessor for the stored raw frequency.
    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .biweekly }
        set { frequencyRaw = newValue.rawValue }
    }
}
