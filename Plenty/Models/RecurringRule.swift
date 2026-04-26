//
//  RecurringRule.swift
//  Plenty
//
//  Target path: Plenty/Models/RecurringRule.swift
//
//  The recurrence policy for a recurring transaction (bill or income).
//  A value type, not a @Model, because:
//    • Recurrence is policy, not data.
//    • CloudKit syncs it cleanly as a single string field.
//    • It's never queried independently.
//
//  Encoded to JSON and stored as a String on the owning model. Use
//  `RecurringRule.decode(from:)` / `.encoded()` at the boundary.
//

import Foundation

struct RecurringRule: Codable, Equatable, Hashable, Sendable {

    // MARK: - Frequency

    enum Frequency: String, Codable, CaseIterable, Identifiable, Sendable {
        case weekly
        case biweekly
        case semimonthly
        case monthly
        case quarterly
        case annually

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .weekly:      return "Weekly"
            case .biweekly:    return "Every 2 Weeks"
            case .semimonthly: return "Twice a Month"
            case .monthly:     return "Monthly"
            case .quarterly:   return "Quarterly"
            case .annually:    return "Yearly"
            }
        }

        var occurrencesPerYear: Double {
            switch self {
            case .weekly:      return 52
            case .biweekly:    return 26
            case .semimonthly: return 24
            case .monthly:     return 12
            case .quarterly:   return 4
            case .annually:    return 1
            }
        }
    }

    // MARK: - Properties

    var frequency: Frequency

    /// The anchor date. For monthly, this determines the due day.
    /// For weekly/biweekly, it determines the weekday and parity.
    var anchorDate: Date

    /// Optional secondary day for semimonthly (e.g. 15 for "1st and 15th").
    var secondDayOfMonth: Int?

    /// When the rule stops generating occurrences. Nil is indefinite.
    var endDate: Date?

    /// Whether the rule is active. Inactive rules generate no new
    /// occurrences but keep their history.
    var isActive: Bool

    // MARK: - Init

    init(
        frequency: Frequency,
        anchorDate: Date,
        secondDayOfMonth: Int? = nil,
        endDate: Date? = nil,
        isActive: Bool = true
    ) {
        self.frequency = frequency
        self.anchorDate = anchorDate
        self.secondDayOfMonth = secondDayOfMonth
        self.endDate = endDate
        self.isActive = isActive
    }

    // MARK: - Occurrence Generation

    func occurrences(inMonth month: Int, year: Int, calendar: Calendar = .current) -> [Date] {
        guard isActive else { return [] }

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard
            let monthStart = calendar.date(from: comps),
            let monthRange = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let daysInMonth = monthRange.count
        comps.day = daysInMonth
        guard let monthEnd = calendar.date(from: comps) else { return [] }

        if let endDate, endDate < monthStart { return [] }
        if anchorDate > monthEnd { return [] }

        switch frequency {
        case .monthly:
            let anchorDay = calendar.component(.day, from: anchorDate)
            let clampedDay = min(anchorDay, daysInMonth)
            comps.day = clampedDay
            if let date = calendar.date(from: comps), isWithinRuleWindow(date) {
                return [date]
            }
            return []

        case .semimonthly:
            let firstDay = calendar.component(.day, from: anchorDate)
            let secondDay = secondDayOfMonth ?? 15
            let clampedDays = Array(Set([firstDay, secondDay].map { min($0, daysInMonth) })).sorted()
            return clampedDays.compactMap { day -> Date? in
                comps.day = day
                guard let date = calendar.date(from: comps), isWithinRuleWindow(date) else { return nil }
                return date
            }

        case .weekly:
            return walkDailyOccurrences(monthStart: monthStart, monthEnd: monthEnd, stepDays: 7, calendar: calendar)

        case .biweekly:
            return walkDailyOccurrences(monthStart: monthStart, monthEnd: monthEnd, stepDays: 14, calendar: calendar)

        case .quarterly:
            return walkMonthlyOccurrences(monthStart: monthStart, monthEnd: monthEnd, stepMonths: 3, calendar: calendar)

        case .annually:
            return walkMonthlyOccurrences(monthStart: monthStart, monthEnd: monthEnd, stepMonths: 12, calendar: calendar)
        }
    }

    private func isWithinRuleWindow(_ date: Date) -> Bool {
        if date < anchorDate { return false }
        if let endDate, date > endDate { return false }
        return true
    }

    private func walkDailyOccurrences(monthStart: Date, monthEnd: Date, stepDays: Int, calendar: Calendar) -> [Date] {
        var results: [Date] = []
        var cursor = anchorDate

        while cursor < monthStart {
            guard let next = calendar.date(byAdding: .day, value: stepDays, to: cursor) else { break }
            cursor = next
        }

        while cursor <= monthEnd {
            if cursor >= monthStart && isWithinRuleWindow(cursor) {
                results.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: stepDays, to: cursor) else { break }
            cursor = next
        }

        return results
    }

    private func walkMonthlyOccurrences(monthStart: Date, monthEnd: Date, stepMonths: Int, calendar: Calendar) -> [Date] {
        var results: [Date] = []
        var cursor = anchorDate

        while cursor < monthStart {
            guard let next = calendar.date(byAdding: .month, value: stepMonths, to: cursor) else { break }
            cursor = next
        }

        while cursor <= monthEnd {
            if cursor >= monthStart && isWithinRuleWindow(cursor) {
                results.append(cursor)
            }
            guard let next = calendar.date(byAdding: .month, value: stepMonths, to: cursor) else { break }
            cursor = next
        }

        return results
    }

    // MARK: - JSON Encoding

    func encoded() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(from string: String?) -> RecurringRule? {
        guard
            let string,
            !string.isEmpty,
            let data = string.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(RecurringRule.self, from: data)
    }

    // MARK: - Convenience Constructors

    static func monthly(onDay day: Int, startingFrom date: Date = .now) -> RecurringRule {
        var comps = Calendar.current.dateComponents([.year, .month], from: date)
        comps.day = day
        let anchor = Calendar.current.date(from: comps) ?? date
        return RecurringRule(frequency: .monthly, anchorDate: anchor)
    }

    static func biweekly(startingFrom date: Date) -> RecurringRule {
        RecurringRule(frequency: .biweekly, anchorDate: date)
    }

    static func semimonthly(firstDay: Int, secondDay: Int, startingFrom date: Date = .now) -> RecurringRule {
        var comps = Calendar.current.dateComponents([.year, .month], from: date)
        comps.day = firstDay
        let anchor = Calendar.current.date(from: comps) ?? date
        return RecurringRule(frequency: .semimonthly, anchorDate: anchor, secondDayOfMonth: secondDay)
    }
}
