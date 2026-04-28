//
//  IncomeEntryGenerator.swift
//  Plenty
//
//  Target path: Plenty/Engine/IncomeEntryGenerator.swift
//
//  Phase 4 (v2): the active-sources fetch now also filters by
//  `rolloverEnabled`. Sources with rollover OFF are dormant — they
//  don't auto-materialize in any month. Users bring them forward
//  manually via the "Copy from previous month" sheet on the Income
//  tab.
//
//  Confirmed and skipped entries from a source are never affected by
//  toggling rollover. Only future expected materializations stop.
//
//  Generates expected income `Transaction` records from active+rolling
//  `IncomeSource` templates. Fully idempotent with the following
//  safety layers:
//
//    • Stable dedupe key "sourceID:yyyy-MM-dd"
//    • Advisory file lock (flock) so concurrent generations serialize
//    • Duplicate reconciliation pass after each save (CloudKit can
//      land duplicates from another device)
//    • Inactive-source cleanup and legacy backfill
//    • Status priority (confirmed > skipped > expected) when pruning
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

    /// Backfill missing dedupe keys, reconcile duplicates, and ensure
    /// the month's expected entries exist. Safest entry point for
    /// surfaces that may run before the iPhone app has opened for the
    /// month (Shortcuts, Watch, widgets).
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
    /// active *and rolling* source. Sources with rolloverEnabled = false
    /// are skipped here (the user opts in via the copy-from-previous
    /// flow on the Income tab).
    func generateExpectedEntries(month: Int, year: Int) throws {
        try withGenerationLock {
            let cal = Calendar.current
            let existing = try fetchIncomeTransactions(month: month, year: year)
            let activeSources = try fetchActiveAndRollingSources()

            var existingKeys = Set(existing.compactMap(\.dedupeKey))
            var insertedCount = 0

            let monthDate = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now

            for source in activeSources {
                let payDates = buildPayDates(for: monthDate, source: source)

                for payDate in payDates {
                    let key = Self.makeDedupeKey(sourceID: source.id, payDate: payDate)

                    // Primary dedupe: keys we've seen.
                    guard !existingKeys.contains(key) else { continue }

                    // Same-source same-day fallback. Catches legacy
                    // entries without a dedupeKey, plus entries whose
                    // key was formed in a different timezone (DST or
                    // travel).
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

    /// Remove every `.expected` entry tied to a given source. Called
    /// when the user deactivates or deletes a source. Confirmed and
    /// skipped entries are preserved as historical record.
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

    /// Defensive sweep for stale `.expected` entries whose source is
    /// now inactive. Intended to run once on app launch. Leaves
    /// nil-source entries alone (could still be in-flight via CloudKit).
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

    /// One-time migration: backfill `dedupeKey` on entries that lack
    /// one, and remove duplicates that share the same key.
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

    // MARK: - Dedupe Key

    static func makeDedupeKey(sourceID: UUID, payDate: Date) -> String {
        "\(sourceID.uuidString):\(Self.dedupeFormatter.string(from: payDate))"
    }

    private static let dedupeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
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
            comps.day = min(source.dayOfMonth, cal.range(of: .day, in: .month, for: monthDate)?.count ?? 28)
            return [cal.date(from: comps)].compactMap { $0 }

        case .semimonthly:
            let firstDay = source.dayOfMonth
            let secondDay = source.secondDayOfMonth ?? 15
            let monthDays = cal.range(of: .day, in: .month, for: monthDate)?.count ?? 28
            var dates: [Date] = []
            for day in [firstDay, secondDay] {
                var comps = cal.dateComponents([.year, .month], from: monthDate)
                comps.day = min(day, monthDays)
                if let d = cal.date(from: comps) { dates.append(d) }
            }
            return dates.sorted()

        case .weekly, .biweekly:
            return weeklyOrBiweeklyPayDates(in: monthDate, source: source, calendar: cal)
        }
    }

    private func weeklyOrBiweeklyPayDates(
        in monthDate: Date,
        source: IncomeSource,
        calendar cal: Calendar
    ) -> [Date] {
        guard let monthRange = cal.range(of: .day, in: .month, for: monthDate) else { return [] }
        let comps = cal.dateComponents([.year, .month], from: monthDate)
        guard let firstOfMonth = cal.date(from: comps) else { return [] }

        // Find the first occurrence of the source.weekday on or after
        // firstOfMonth.
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1  // 0-indexed
        let target = source.weekday
        var offset = (target - firstWeekday + 7) % 7
        guard let firstHit = cal.date(byAdding: .day, value: offset, to: firstOfMonth) else { return [] }

        var dates: [Date] = []
        var current = firstHit
        let stride: Int = source.frequency == .weekly ? 7 : 14

        // For biweekly, snap to the parity defined by biweeklyAnchor.
        if source.frequency == .biweekly, let anchor = source.biweeklyAnchor {
            let daysFromAnchor = cal.dateComponents([.day], from: anchor, to: current).day ?? 0
            let parity = ((daysFromAnchor % 14) + 14) % 14
            if parity != 0 {
                let shift = parity <= 7 ? -parity : (14 - parity)
                if let adjusted = cal.date(byAdding: .day, value: shift, to: current) {
                    current = adjusted
                }
            }
        }

        // Walk through the month emitting dates that fall in range.
        while cal.component(.month, from: current) == comps.month {
            if cal.component(.day, from: current) >= 1,
               cal.component(.day, from: current) <= monthRange.count {
                dates.append(current)
            }
            guard let next = cal.date(byAdding: .day, value: stride, to: current) else { break }
            current = next
        }

        return dates
    }

    // MARK: - Fetches

    private func fetchIncomeTransactions(month: Int, year: Int) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                tx.kindRaw == "income" && tx.month == month && tx.year == year
            }
        )
        return try context.fetch(descriptor)
    }

    /// v2 — only sources that are both active AND have rollover enabled.
    /// Sources with rollover OFF are valid templates the user wants to
    /// keep around but doesn't want auto-materializing each month.
    private func fetchActiveAndRollingSources() throws -> [IncomeSource] {
        let descriptor = FetchDescriptor<IncomeSource>(
            predicate: #Predicate { source in
                source.isActive && source.rolloverEnabled
            }
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Duplicate Reconciliation

    /// When two transactions share the same dedupeKey (e.g. one from
    /// local generation, one synced via CloudKit), keep the highest
    /// status priority and drop the other.
    private func reconcileDuplicates(in transactions: [Transaction]) throws -> Int {
        var byKey: [String: [Transaction]] = [:]
        for tx in transactions {
            guard let key = tx.dedupeKey else { continue }
            byKey[key, default: []].append(tx)
        }

        var deletedCount = 0
        for (_, group) in byKey where group.count > 1 {
            // Status priority: confirmed > skipped > expected
            let sorted = group.sorted { lhs, rhs in
                statusPriority(lhs.incomeStatus) > statusPriority(rhs.incomeStatus)
            }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                deletedCount += 1
            }
        }
        return deletedCount
    }

    private func statusPriority(_ status: IncomeStatus) -> Int {
        switch status {
        case .confirmed: return 2
        case .skipped:   return 1
        case .expected:  return 0
        }
    }

    // MARK: - Generation Lock

    /// Wrap the generation block in an advisory file lock so concurrent
    /// invocations (Watch + iPhone, intent + app) serialize.
    private func withGenerationLock<T>(_ body: () throws -> T) throws -> T {
        guard let lockURL = lockFileURL() else {
            return try body()
        }

        // Ensure the lock file exists.
        if !FileManager.default.fileExists(atPath: lockURL.path) {
            FileManager.default.createFile(atPath: lockURL.path, contents: nil)
        }

        let fd = open(lockURL.path, O_RDWR)
        guard fd >= 0 else {
            return try body()
        }
        defer { close(fd) }

        flock(fd, LOCK_EX)
        defer { flock(fd, LOCK_UN) }

        return try body()
    }

    private func lockFileURL() -> URL? {
        let appGroupID = "group.com.plenty.app"
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent(Self.generationLockFilename)
        }
        return containerURL.appendingPathComponent(Self.generationLockFilename)
    }
}
