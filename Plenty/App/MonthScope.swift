//
//  MonthScope.swift
//  Plenty
//
//  Target path: Plenty/App/MonthScope.swift
//
//  Phase 0 (v2): the month/year currently scoped by the four-tab UI.
//
//  Every v2 tab (Overview, Income, Expenses, Plan) reads from a shared
//  MonthScope instance injected via @Environment. The MonthNavigator
//  component (DesignSystem/Components/MonthNavigator.swift) is the only
//  view that mutates it; all other views observe and re-render when the
//  user steps to a new month.
//
//  Default state on each cold launch is the current calendar month. Past
//  and future months are equally accessible — PDS §3.1: "All months
//  fully editable (back-fill or pre-plan freely)."
//
//  This type is intentionally lightweight: just two ints and a small
//  surface of navigation/query helpers. All date math goes through an
//  injectable Calendar so tests can pin a specific calendar/timezone.
//

import Foundation
import Observation

@Observable
@MainActor
final class MonthScope {

    // MARK: - State

    /// The month currently in focus (1–12).
    private(set) var month: Int

    /// The year currently in focus (e.g. 2026).
    private(set) var year: Int

    // MARK: - Init

    /// Initializes scope to the calendar month containing `reference`.
    init(reference: Date = .now, calendar: Calendar = .current) {
        self.month = calendar.component(.month, from: reference)
        self.year  = calendar.component(.year,  from: reference)
    }

    // MARK: - Navigation

    /// Step forward one month. December → January of the next year.
    func stepForward(calendar: Calendar = .current) {
        guard
            let current = makeDate(month: month, year: year, calendar: calendar),
            let next = calendar.date(byAdding: .month, value: 1, to: current)
        else { return }
        applyDate(next, calendar: calendar)
    }

    /// Step back one month. January → December of the previous year.
    func stepBack(calendar: Calendar = .current) {
        guard
            let current = makeDate(month: month, year: year, calendar: calendar),
            let previous = calendar.date(byAdding: .month, value: -1, to: current)
        else { return }
        applyDate(previous, calendar: calendar)
    }

    /// Jump to the calendar month containing the given date.
    func jumpTo(date: Date, calendar: Calendar = .current) {
        applyDate(date, calendar: calendar)
    }

    /// Reset to the calendar month containing `reference` (default: now).
    func resetToCurrent(reference: Date = .now, calendar: Calendar = .current) {
        applyDate(reference, calendar: calendar)
    }

    // MARK: - Queries

    /// True when the scope matches the calendar month containing `reference`.
    func isCurrentMonth(reference: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.component(.month, from: reference) == month
            && calendar.component(.year, from: reference) == year
    }

    /// True when the scope is strictly in the future of `reference`.
    func isFutureMonth(reference: Date = .now, calendar: Calendar = .current) -> Bool {
        compareTo(reference: reference, calendar: calendar) == .orderedDescending
    }

    /// True when the scope is strictly in the past of `reference`.
    func isPastMonth(reference: Date = .now, calendar: Calendar = .current) -> Bool {
        compareTo(reference: reference, calendar: calendar) == .orderedAscending
    }

    /// First day of the scoped month (used for date-range queries).
    func firstOfMonth(calendar: Calendar = .current) -> Date {
        makeDate(month: month, year: year, calendar: calendar) ?? .now
    }

    /// Localized "April 2026" style label.
    var displayLabel: String {
        guard let date = makeDate(month: month, year: year, calendar: .current) else {
            return "\(month)/\(year)"
        }
        return date.formatted(.dateTime.month(.wide).year())
    }

    // MARK: - Private

    private func applyDate(_ date: Date, calendar: Calendar) {
        let newMonth = calendar.component(.month, from: date)
        let newYear  = calendar.component(.year,  from: date)
        guard newMonth != month || newYear != year else { return }
        month = newMonth
        year = newYear
    }

    private func makeDate(month: Int, year: Int, calendar: Calendar) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        return calendar.date(from: comps)
    }

    private func compareTo(reference: Date, calendar: Calendar) -> ComparisonResult {
        let refMonth = calendar.component(.month, from: reference)
        let refYear  = calendar.component(.year,  from: reference)
        if year != refYear { return year < refYear ? .orderedAscending : .orderedDescending }
        if month != refMonth { return month < refMonth ? .orderedAscending : .orderedDescending }
        return .orderedSame
    }
}
