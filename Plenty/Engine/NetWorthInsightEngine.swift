//
//  NetWorthInsightEngine.swift
//  Plenty
//
//  Target path: Plenty/Engine/NetWorthInsightEngine.swift
//
//  Pure-function calculator for the Net Worth detail screen. Two
//  outputs:
//
//    • historyPoints(accounts:timeframe:) — month-bucketed
//      [HistoryPoint] of net worth, assets, and debt over the
//      requested window, derived from AccountBalance snapshots
//      with a fallback to each account's current balance.
//
//    • insights(from:) — 0–3 plain-language statements like
//      "You grew $X this quarter" or "Debt down $Y this year".
//      Conservative: nothing fires below a $100 absolute movement.
//
//  No SwiftUI, no SwiftData mutations. Easy to unit-test.
//

import Foundation

enum NetWorthInsightEngine {

    // MARK: - Timeframe

    enum Timeframe: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
        case threeMonths
        case sixMonths
        case oneYear
        case allTime

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .threeMonths: return "3M"
            case .sixMonths:   return "6M"
            case .oneYear:     return "1Y"
            case .allTime:     return "All"
            }
        }

        /// Number of trailing months to bucket. Nil for `.allTime`,
        /// which is computed from the earliest snapshot.
        var months: Int? {
            switch self {
            case .threeMonths: return 3
            case .sixMonths:   return 6
            case .oneYear:     return 12
            case .allTime:     return nil
            }
        }
    }

    // MARK: - History Point

    struct HistoryPoint: Identifiable, Hashable, Sendable {
        let bucketEnd: Date
        let netWorth: Decimal
        let assets: Decimal
        let debt: Decimal

        var id: Date { bucketEnd }
    }

    // MARK: - Insight

    struct Insight: Identifiable, Hashable, Sendable {
        enum Kind: String, Sendable { case growth, decline, neutral }

        let id: String
        let kind: Kind
        let title: String
        let detail: String
    }

    // MARK: - History

    /// Bucket the last N months into HistoryPoint values. For each bucket
    /// the balance used is the latest AccountBalance recorded on or
    /// before the end of the month, falling back to the account's
    /// current balance when no snapshot exists.
    static func historyPoints(accounts: [Account], timeframe: Timeframe) -> [HistoryPoint] {
        guard !accounts.isEmpty else { return [] }

        let cal = Calendar.current
        let now = Date.now
        let count = bucketCount(for: timeframe, accounts: accounts, calendar: cal, now: now)
        guard count > 0 else { return [] }

        var result: [HistoryPoint] = []
        result.reserveCapacity(count)

        for offset in (0..<count).reversed() {
            guard let monthDate = cal.date(byAdding: .month, value: -offset, to: now) else { continue }
            let bucketEnd = cal.endOfMonth(for: monthDate)

            var assets: Decimal = 0
            var debt: Decimal = 0
            for account in accounts {
                let balance = latestSnapshot(for: account, on: bucketEnd)
                if account.isAsset {
                    assets += balance
                } else {
                    debt += balance
                }
            }

            result.append(HistoryPoint(
                bucketEnd: bucketEnd,
                netWorth: assets - debt,
                assets: assets,
                debt: debt
            ))
        }

        return result
    }

    // MARK: - Insights

    /// Produce 0–3 plain-language insights from a history series.
    /// Conservative thresholds: the absolute change must exceed
    /// $100 before an insight is generated.
    static func insights(from points: [HistoryPoint]) -> [Insight] {
        guard let first = points.first, let last = points.last, points.count >= 2 else {
            return []
        }

        let netDelta    = last.netWorth - first.netWorth
        let assetDelta  = last.assets   - first.assets
        let debtDelta   = last.debt     - first.debt

        let threshold: Decimal = 100

        var output: [Insight] = []

        // Net worth movement
        if abs(netDelta) >= threshold {
            let kind: Insight.Kind = netDelta > 0 ? .growth : .decline
            let verb = netDelta > 0 ? "grew" : "fell"
            let span = spanLabel(from: first.bucketEnd, to: last.bucketEnd)
            output.append(Insight(
                id: "netWorth",
                kind: kind,
                title: "Net worth \(verb) \(abs(netDelta).asCleanCurrency())",
                detail: "\(span). Tracked from your account balance updates."
            ))
        }

        // Debt movement (down is good)
        if abs(debtDelta) >= threshold {
            let kind: Insight.Kind = debtDelta < 0 ? .growth : .decline
            let verb = debtDelta < 0 ? "down" : "up"
            output.append(Insight(
                id: "debt",
                kind: kind,
                title: "Debt \(verb) \(abs(debtDelta).asCleanCurrency())",
                detail: debtDelta < 0
                    ? "You've paid down what you owe across the period."
                    : "Balances on credit and loan accounts are higher."
            ))
        }

        // Asset movement, only if it materially differs from net worth.
        if abs(assetDelta) >= threshold && abs(assetDelta - netDelta) >= threshold {
            let kind: Insight.Kind = assetDelta > 0 ? .growth : .decline
            let verb = assetDelta > 0 ? "up" : "down"
            output.append(Insight(
                id: "assets",
                kind: kind,
                title: "Assets \(verb) \(abs(assetDelta).asCleanCurrency())",
                detail: "Cash and investments combined."
            ))
        }

        return Array(output.prefix(3))
    }

    // MARK: - Helpers

    private static func bucketCount(
        for timeframe: Timeframe,
        accounts: [Account],
        calendar cal: Calendar,
        now: Date
    ) -> Int {
        if let months = timeframe.months {
            return months
        }
        // .allTime — from the earliest snapshot to now, capped at 60 months
        // so the chart stays legible.
        let earliest = accounts
            .flatMap { $0.balanceHistory ?? [] }
            .map(\.recordedAt)
            .min()
        guard let earliest else { return 6 }

        let comps = cal.dateComponents([.month], from: earliest, to: now)
        let months = max(2, (comps.month ?? 0) + 1)
        return min(months, 60)
    }

    private static func latestSnapshot(for account: Account, on date: Date) -> Decimal {
        let snapshots = (account.balanceHistory ?? [])
            .filter { $0.recordedAt <= date }
            .sorted { $0.recordedAt > $1.recordedAt }
        return snapshots.first?.balance ?? account.balance
    }

    private static func spanLabel(from start: Date, to end: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.month], from: start, to: end)
        let months = comps.month ?? 0
        switch months {
        case ..<2:  return "Over the past month"
        case 2..<4: return "Over the past quarter"
        case 4..<7: return "Over the past 6 months"
        case 7..<13: return "Over the past year"
        default:    return "Over the period"
        }
    }
}

