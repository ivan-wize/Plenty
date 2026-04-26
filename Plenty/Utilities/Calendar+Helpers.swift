//
//  Calendar+Helpers.swift
//  Plenty
//
//  Target path: Plenty/Utilities/Calendar+Helpers.swift
//
//  Copied forward from Left v1.0 unchanged. Used by the engine layer
//  and any view that needs month boundaries or day clamping.
//

import Foundation

extension Calendar {

    /// First moment of the month containing `date`.
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    /// Last moment of the month containing `date`, as the start of the
    /// last day (not 23:59:59).
    func endOfMonth(for date: Date) -> Date {
        guard let nextMonth = self.date(byAdding: .month, value: 1, to: startOfMonth(for: date)),
              let lastDay = self.date(byAdding: .day, value: -1, to: nextMonth)
        else { return date }
        return startOfDay(for: lastDay)
    }

    /// Clamp a day number to the valid range for a given month.
    /// For example, day 31 in February returns February 28 or 29.
    func dateByClampingDay(_ day: Int, withinMonthOf monthDate: Date) -> Date? {
        let comps = dateComponents([.year, .month], from: monthDate)
        guard let year = comps.year, let month = comps.month else { return nil }

        let range = self.range(of: .day, in: .month, for: monthDate) ?? 1..<29
        let clampedDay = max(range.lowerBound, min(range.upperBound - 1, day))

        return self.date(from: DateComponents(year: year, month: month, day: clampedDay))
    }
}
