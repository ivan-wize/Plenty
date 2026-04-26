//
//  IncomeEntryGenerator.swift
//  Plenty
//
//  Target path: Plenty/Engine/IncomeEntryGenerator.swift
//
//  Generates expected income `Transaction` records from active
//  `IncomeSource` templates. Fully idempotent with the following safety
//  layers:
//
//    • Stable dedupe key "sourceID:yyyy-MM-dd"
//    • Advisory file lock (flock) so concurrent generations serialize
//    • Duplicate reconciliation pass after each save (CloudKit can
//      land duplicates from another device)
//    • Inactive-source cleanup and legacy backfill
//    • Status priority (confirmed > skipped > expected) when pruning
//
//  Port from Left. Logger subsystem renamed to com.plenty.app. App
//  Group ID renamed to group.com.plenty.app for the lock file path.
//

import Foundation
import SwiftData
import Darwin
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "income-generator")

@MainActor
final class IncomeEntryGenerator {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Public API

    /// Backfill missing dedupe keys, reconcile duplicates, and ensure the
    /// month's expected entries exist. Safest entry point for surfaces
    /// that may run before the iPhone app has opened for the month
    /// (Shortcuts, Watch, widgets).
    func prepareExpectedEntries(
        month: Int,
        year: Int,
        includeInactiveSourceCleanup: Bool = false
    ) throws {
        if includeInactiveSourceCleanup {
            _ = try purgeInactiveSourceExpectedEntries()
        }
        _ = try backfillDedupeKeys()
        try generateExpectedEntries(month: month, year: year)
    }

    /// Generate expected income transactions for a month from every
    /// active source. Uses the dedupe key, advisory lock, and
    /// reconciliation pass to handle concurrent and cross-device cases.
    func generateExpectedEntries(month: Int, year: Int) throws {
        try withGenerationLock {
            let cal = Calendar.current
            let existing = try fetchIncomeTransactions(month: month, year: year)
            let activeSources = try fetchActiveSources()

            var existingKeys = Set(existing.compactMap(\.dedupeKey))
            var insertedCount = 0

            let monthDate = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now

            for source in activeSources {
                let payDates = buildPayDates(for: monthDate, source: source)

                for payDate in payDates {
                    let key = Self.makeDedupeKey(sourceID: source.id, payDate: payDate)

                    // Primary dedupe: keys we've seen.
                    guard !existingKeys.contains(key) else { continue }

                    // Same-source same-day fallback. Catches legacy entries
                    // without a dedupeKey, plus entries whose key was formed
                    // in a different timezone (DST or travel).
                    let sameDayMatch = existing.contains { tx in
                        tx.incomeSource?.id == source.id &&
                        cal.isDate(tx.date, inSameDayAs: payDate)
                    }
                    guard !sameDayMatch else { continue }

                    let tx = Transaction.expectedIncome(
                        name: source.name,
                        expectedAmount: source.expectedAmount,
                        date: payDate,
                        source: source
                    )
                    context.insert(tx)
                    existingKeys.insert(key)
                    insertedCount += 1
                }
            }

            if insertedCount > 0 {
                try context.save()
            }

            let deduped = try reconcileDuplicates(in: fetchIncomeTransactions(month: month, year: year))
            if deduped > 0 {
                try context.save()
            }
        }
    }

    // MARK: - Source Lifecycle

    /// Remove every `.expected` entry tied to a given source. Called when
    /// the user deactivates or deletes a source. Confirmed and skipped
    /// entries are preserved as historical record.
    @discardableResult
    func purgeExpectedEntries(for source: IncomeSource) throws -> Int {
        let targetID = source.id
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                tx.kindRaw == "income" && tx.incomeStatusRaw == "expected"
            }
        )
        let allExpected = try context.fetch(descriptor)
        let toDelete = allExpected.filter { $0.incomeSource?.id == targetID }

        for tx in toDelete {
            context.delete(tx)
        }
        if !toDelete.isEmpty {
            try context.save()
        }
        return toDelete.count
    }

    /// Defensive sweep for stale `.expected` entries whose source is now
    /// inactive. Intended to run once on app launch. Leaves nil-source
    /// entries alone (could still be in-flight via CloudKit).
    @discardableResult
    func purgeInactiveSourceExpectedEntries() throws -> Int {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                tx.kindRaw == "income" && tx.incomeStatusRaw == "expected"
            }
        )
        let allExpected = try context.fetch(descriptor)
        let stale = allExpected.filter { tx in
            guard let source = tx.incomeSource else { return false }
            return !source.isActive
        }

        for tx in stale {
            context.delete(tx)
        }
        if !stale.isEmpty {
            try context.save()
        }
        return stale.count
    }

    /// One-time migration: backfill `dedupeKey` on entries that lack one,
    /// and remove duplicates that share the same key.
    @discardableResult
    func backfillDedupeKeys() throws -> (backfilled: Int, deduped: Int) {
        try withGenerationLock {
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { tx in tx.kindRaw == "income" }
            )
            let allIncome = try context.fetch(descriptor)

            var backfilled = 0
            for tx in allIncome where tx.dedupeKey == nil {
                guard let source = tx.incomeSource else { continue }
                tx.dedupeKey = Self.makeDedupeKey(sourceID: source.id, payDate: tx.date)
                backfilled += 1
            }

            let deduped = try reconcileDuplicates(in: allIncome)

            if backfilled > 0 || deduped > 0 {
                try context.save()
            }
            return (backfilled, deduped)
        }
    }

    // MARK: - Key

    static func makeDedupeKey(sourceID: UUID, payDate: Date) -> String {
        "\(sourceID.uuidString):\(Self.dedupeFormatter.string(from: payDate))"
    }

    private static let dedupeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        // Fixed UTC so the key is stable across TZ changes and DST. The
        // same-day fallback in the dedupe check handles cases where a
        // stored date drifts across calendar days between timezones.
        f.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return f
    }()

    private static let generationLockFilename = "income-entry-generation.lock"

    // MARK: - Pay Date Generation

    private func buildPayDates(for monthDate: Date, source: IncomeSource) -> [Date] {
        let cal = Calendar.current

        switch source.frequency {
        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: monthDate)
            comps.day = min(source.dayOfMonth, cal.range(of: .day, in: .month, for: monthDate)?.count ?? source.dayOfMonth)
            return [cal.date(from: comps)].compactMap { $0 }

        case .semimonthly:
            var dates: [Date] = []
            let daysInMonth = cal.range(of: .day, in: .month, for: monthDate)?.count ?? 31
            for day in [source.dayOfMonth, source.secondDayOfMonth ?? 15] {
                var comps = cal.dateComponents([.year, .month], from: monthDate)
                comps.day = min(day, daysInMonth)
                if let date = cal.date(from: comps) {
                    dates.append(date)
                }
            }
            return dates.sorted()

        case .weekly:
            return weeklyOccurrences(in: monthDate, weekday: source.weekday, every: 7, anchor: source.biweeklyAnchor)

        case .biweekly:
            return weeklyOccurrences(in: monthDate, weekday: source.weekday, every: 14, anchor: source.biweeklyAnchor)
        }
    }

    private func weeklyOccurrences(in monthDate: Date, weekday: Int, every stepDays: Int, anchor: Date?) -> [Date] {
        let cal = Calendar.current
        guard
            let monthStart = cal.dateInterval(of: .month, for: monthDate)?.start,
            let monthEndExclusive = cal.dateInterval(of: .month, for: monthDate)?.end
        else { return [] }

        let monthEnd = cal.date(byAdding: .second, value: -1, to: monthEndExclusive) ?? monthEndExclusive

        // Start from anchor or first matching weekday in the month.
        var cursor: Date
        if let anchor {
            cursor = anchor
            while cursor < monthStart {
                guard let next = cal.date(byAdding: .day, value: stepDays, to: cursor) else { return [] }
                cursor = next
            }
        } else {
            // First occurrence of weekday in month.
            var comps = cal.dateComponents([.year, .month], from: monthDate)
            comps.day = 1
            guard let monthFirst = cal.date(from: comps) else { return [] }
            let firstWeekday = cal.component(.weekday, from: monthFirst) - 1  // Sunday=0
            let offset = (weekday - firstWeekday + 7) % 7
            cursor = cal.date(byAdding: .day, value: offset, to: monthFirst) ?? monthFirst
        }

        var results: [Date] = []
        while cursor <= monthEnd {
            if cursor >= monthStart {
                results.append(cursor)
            }
            guard let next = cal.date(byAdding: .day, value: stepDays, to: cursor) else { break }
            cursor = next
        }
        return results
    }

    // MARK: - Fetching

    private func fetchIncomeTransactions(month: Int, year: Int) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                tx.kindRaw == "income" && tx.month == month && tx.year == year
            }
        )
        return try context.fetch(descriptor)
    }

    private func fetchActiveSources() throws -> [IncomeSource] {
        let descriptor = FetchDescriptor<IncomeSource>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\IncomeSource.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Duplicate Reconciliation

    private func reconcileDuplicates(in transactions: [Transaction]) throws -> Int {
        let keyed = Dictionary(grouping: transactions.compactMap { tx -> (String, Transaction)? in
            guard let key = tx.dedupeKey else { return nil }
            return (key, tx)
        }, by: \.0)

        var deletedCount = 0

        for group in keyed.values {
            let duplicates = group.map(\.1)
            guard duplicates.count > 1, let survivor = preferredSurvivor(in: duplicates) else {
                continue
            }

            for tx in duplicates where tx.persistentModelID != survivor.persistentModelID {
                context.delete(tx)
                deletedCount += 1
            }
        }

        return deletedCount
    }

    /// Survivor priority: confirmed > skipped > expected; tiebreak by
    /// earliest createdAt so behavior is stable across runs.
    private func preferredSurvivor(in transactions: [Transaction]) -> Transaction? {
        transactions.reduce(nil) { currentBest, candidate in
            guard let currentBest else { return candidate }
            return shouldPrefer(candidate, over: currentBest) ? candidate : currentBest
        }
    }

    private func shouldPrefer(_ candidate: Transaction, over current: Transaction) -> Bool {
        let candidateRank = statusRank(candidate.incomeStatus)
        let currentRank = statusRank(current.incomeStatus)
        if candidateRank != currentRank { return candidateRank > currentRank }
        return candidate.createdAt < current.createdAt
    }

    private func statusRank(_ status: IncomeStatus) -> Int {
        switch status {
        case .confirmed: return 2
        case .skipped:   return 1
        case .expected:  return 0
        }
    }

    // MARK: - Advisory Lock

    /// Serialize generations across same-process contexts. CloudKit
    /// duplicates from another device are handled by reconcileDuplicates.
    private func withGenerationLock<T>(_ work: () throws -> T) throws -> T {
        let url = lockFileURL()
        let fd = open(url.path, O_RDWR | O_CREAT, 0o644)
        guard fd >= 0 else {
            // Lock file unavailable; proceed without serialization.
            // Reconciliation still cleans up any duplicates that result.
            return try work()
        }
        defer { close(fd) }

        let lockResult = flock(fd, LOCK_EX)
        if lockResult != 0 {
            // Failed to acquire lock; proceed unlocked. Reconciliation
            // catches any resulting duplicates.
            logger.warning("Failed to acquire generation lock; proceeding unlocked")
            return try work()
        }
        defer { _ = flock(fd, LOCK_UN) }

        return try work()
    }

    private func lockFileURL() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return dir.appendingPathComponent(Self.generationLockFilename)
    }
}
