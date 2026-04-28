//
//  TheReadCache.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/TheRead/TheReadCache.swift
//
//  Phase 4: daily cache for the inline Read on Home.
//  Phase 7 update: + separate weekly cache for the Sunday Read
//  notification. Daily and weekly are independent — generating one
//  does not refresh the other.
//
//  Daily cache invalidates at midnight; weekly invalidates at the
//  start of each week (Sunday).
//

import Foundation
import Observation

@Observable
@MainActor
final class TheReadCache {

    // MARK: - Daily State (Phase 4)

    /// The most recent daily Read (one of: silence, paceWarning,
    /// paceTrend, billReminder, incomeReminder, milestone).
    private(set) var current: TheRead?

    private(set) var isGenerating = false
    private var lastGeneratedAt: Date?

    // MARK: - Weekly State (Phase 7)

    /// The most recent weekly (Sunday) Read.
    private(set) var weeklyCurrent: TheRead?

    private(set) var isGeneratingWeekly = false
    private var lastWeeklyGeneratedAt: Date?

    // MARK: - Daily Surface

    /// Ensure the daily cache contains a Read for today.
    func ensureFresh(snapshot: PlentySnapshot) async {
        if isFreshForToday() { return }
        await regenerate(snapshot: snapshot)
    }

    func invalidate() {
        lastGeneratedAt = nil
        current = nil
    }

    func regenerate(snapshot: PlentySnapshot) async {
        isGenerating = true
        defer { isGenerating = false }

        let read = await TheReadEngine.generate(snapshot: snapshot)
        current = read
        lastGeneratedAt = .now
    }

    private func isFreshForToday(calendar: Calendar = .current) -> Bool {
        guard let lastGeneratedAt, current != nil else { return false }
        return calendar.isDateInToday(lastGeneratedAt)
    }

    // MARK: - Weekly Surface (Phase 7)

    /// Ensure a weekly Read exists for the current week. Used by
    /// NotificationScheduler before scheduling the Sunday Read.
    func ensureFreshWeekly(snapshot: PlentySnapshot) async {
        if isFreshForThisWeek() { return }
        await regenerateWeekly(snapshot: snapshot)
    }

    func invalidateWeekly() {
        lastWeeklyGeneratedAt = nil
        weeklyCurrent = nil
    }

    func regenerateWeekly(snapshot: PlentySnapshot) async {
        isGeneratingWeekly = true
        defer { isGeneratingWeekly = false }

        let read = await TheReadEngine.generateWeekly(snapshot: snapshot)
        weeklyCurrent = read
        lastWeeklyGeneratedAt = .now
    }

    private func isFreshForThisWeek(calendar: Calendar = .current) -> Bool {
        guard let lastWeeklyGeneratedAt, weeklyCurrent != nil else { return false }
        let lastWeek = calendar.component(.weekOfYear, from: lastWeeklyGeneratedAt)
        let lastYear = calendar.component(.yearForWeekOfYear, from: lastWeeklyGeneratedAt)
        let nowWeek = calendar.component(.weekOfYear, from: .now)
        let nowYear = calendar.component(.yearForWeekOfYear, from: .now)
        return lastWeek == nowWeek && lastYear == nowYear
    }
}
