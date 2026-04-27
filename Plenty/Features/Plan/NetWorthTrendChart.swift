//
//  NetWorthTrendChart.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/NetWorthTrendChart.swift
//
//  Six-month net worth trend, computed from AccountBalance snapshot
//  history. For each of the last 6 months, takes the latest snapshot
//  per account and sums them with the standard sign convention
//  (assets positive, liabilities negative). Renders as a line chart
//  with sage stroke.
//
//  Replaces the prior NetWorthTrendChart. One change: AccountBalance
//  exposes its timestamp as `recordedAt`, not `date` — the prior
//  filter sort referenced a non-existent property.
//

import SwiftUI
import Charts

struct NetWorthTrendChart: View {

    let accounts: [Account]

    private var monthlyNetWorth: [DataPoint] {
        guard !accounts.isEmpty else { return [] }

        let cal = Calendar.current
        let now = Date.now
        var results: [DataPoint] = []

        for offset in (0..<6).reversed() {
            guard let monthDate = cal.date(byAdding: .month, value: -offset, to: now) else { continue }
            let endOfMonth = cal.endOfMonth(for: monthDate)

            let netWorth = accounts.reduce(Decimal.zero) { partial, account in
                let snapshot = latestSnapshot(account: account, before: endOfMonth)
                let signedBalance = account.isAsset ? snapshot : -snapshot
                return partial + signedBalance
            }

            results.append(DataPoint(
                month: cal.date(from: cal.dateComponents([.year, .month], from: monthDate)) ?? monthDate,
                label: monthLabelForOffset(offset, calendar: cal, now: now),
                netWorth: netWorth
            ))
        }

        return results
    }

    private var hasEnoughData: Bool {
        monthlyNetWorth.count >= 2
    }

    private var trendDelta: Decimal? {
        guard let first = monthlyNetWorth.first, let last = monthlyNetWorth.last else { return nil }
        return last.netWorth - first.netWorth
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !hasEnoughData {
                emptyState
            } else {
                chart
                    .frame(height: 200)

                if let delta = trendDelta {
                    deltaLabel(delta)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Net Worth")
                .font(Typography.Title.small)
            Text("Last 6 months")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(monthlyNetWorth) { point in
            LineMark(
                x: .value("Month", point.label),
                y: .value("Net Worth", (point.netWorth as NSDecimalNumber).doubleValue)
            )
            .foregroundStyle(Theme.sage)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.monotone)

            AreaMark(
                x: .value("Month", point.label),
                y: .value("Net Worth", (point.netWorth as NSDecimalNumber).doubleValue)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.sage.opacity(0.3), Theme.sage.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Month", point.label),
                y: .value("Net Worth", (point.netWorth as NSDecimalNumber).doubleValue)
            )
            .foregroundStyle(Theme.sage)
            .symbolSize(36)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(Theme.Opacity.hairline))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount.compactCurrency())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisValueLabel(centered: true)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Delta

    private func deltaLabel(_ delta: Decimal) -> some View {
        HStack(spacing: 6) {
            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(delta >= 0 ? Theme.sage : Theme.terracotta)

            let absDelta = (delta < 0 ? -delta : delta).asPlainCurrency()
            Text("\(delta >= 0 ? "+" : "−")\(absDelta) over 6 months")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not enough history yet")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)

            Text("Plenty needs at least two months of account balance updates to draw a trend. Update your account balances each month to build the picture.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func latestSnapshot(account: Account, before date: Date) -> Decimal {
        let snapshots = (account.balanceHistory ?? [])
            .filter { $0.recordedAt <= date }
            .sorted { $0.recordedAt > $1.recordedAt }

        return snapshots.first?.balance ?? account.balance
    }

    private func monthLabelForOffset(_ offset: Int, calendar: Calendar, now: Date) -> String {
        guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    // MARK: - Data Point

    private struct DataPoint: Identifiable, Hashable {
        let month: Date
        let label: String
        let netWorth: Decimal

        var id: Date { month }
    }
}

// MARK: - Local helpers

private extension Double {
    func compactCurrency() -> String {
        let absValue = abs(self)
        if absValue >= 1_000_000 {
            return String(format: "$%.1fM", self / 1_000_000)
        }
        if absValue >= 1_000 {
            return String(format: "$%.0fk", self / 1_000)
        }
        return String(format: "$%.0f", self)
    }
}

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
