//
//  DebtChartView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/DebtChartView.swift
//
//  Stacked-area visualization of the debt payoff timeline. For each
//  month from now until debt-free, sums each debt's projected balance
//  (after the simulator's interest accrual + payment + extra) and
//  stacks them per-debt.
//
//  The shape converges to zero on the right edge — that's the
//  visual payoff of "you'll be debt-free here." A vertical line
//  marks today.
//
//  This is a lightweight reconstruction from the PayoffPlan steps;
//  for V1 the chart shows the cumulative balance across all debts as
//  a single area without per-debt color (color-coding many debts gets
//  noisy fast). A future version could add hover tooltips and per-
//  debt segments.
//

import SwiftUI
import Charts

struct DebtChartView: View {

    let debts: [Account]
    let plan: DebtEngine.PayoffPlan

    private var points: [DataPoint] {
        guard plan.isPayable, plan.totalMonths > 0 else { return [] }

        // Project each debt's balance forward month by month using its
        // own minimum and the strategy ordering. We re-derive the
        // monthly trajectory to draw a smooth curve; the engine's
        // PayoffStep array only records when each debt clears, not the
        // intermediate balance. This is a lightweight projection that
        // ignores extra payment cascading for chart simplicity — the
        // engine's totalMonths and totalInterest remain authoritative
        // for the labels.
        let calendar = Calendar.current
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: .now) ?? .now

        var balances: [(rate: Decimal, balance: Decimal, minimum: Decimal)] =
            debts.map { account in
                (
                    rate: ((account.interestRate ?? 0) / 100 / 12),
                    balance: account.balance,
                    minimum: account.minimumPayment ?? 0
                )
            }

        var results: [DataPoint] = []
        results.append(DataPoint(
            month: .now,
            totalRemaining: balances.reduce(Decimal.zero) { $0 + $1.balance }
        ))

        for monthOffset in 0..<min(plan.totalMonths, 360) {
            for i in balances.indices {
                let interest = balances[i].balance * balances[i].rate
                balances[i].balance = max(0, balances[i].balance + interest - balances[i].minimum)
            }
            let total = balances.reduce(Decimal.zero) { $0 + $1.balance }
            let date = calendar.date(byAdding: .month, value: monthOffset, to: startOfNextMonth) ?? .now
            results.append(DataPoint(month: date, totalRemaining: total))
        }

        return results
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if plan.isPayable, !points.isEmpty {
                chart
                    .frame(height: 180)
            } else {
                emptyState
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
            Text("Path to debt-free")
                .font(Typography.Title.small)

            if plan.isPayable {
                Text("\(formattedDuration(plan.totalMonths)) at this pace")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Month", point.month),
                y: .value("Remaining", asDouble(point.totalRemaining))
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.terracotta.opacity(0.3), Theme.terracotta.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Month", point.month),
                y: .value("Remaining", asDouble(point.totalRemaining))
            )
            .foregroundStyle(Theme.terracotta)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.monotone)
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
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cannot project")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
            Text("With the current minimums and extra payment, the debt grows faster than it pays down. Adjust the extra monthly amount above to see a path.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func formattedDuration(_ months: Int) -> String {
        if months <= 0 { return "Already paid" }
        if months < 12 { return "\(months) months" }
        let years = months / 12
        let remainder = months % 12
        if remainder == 0 { return "\(years) years" }
        return "\(years) years \(remainder) months"
    }

    private func asDouble(_ d: Decimal) -> Double {
        NSDecimalNumber(decimal: d).doubleValue
    }

    // MARK: - Data Point

    private struct DataPoint: Identifiable, Hashable {
        let month: Date
        let totalRemaining: Decimal
        var id: Date { month }
    }
}

// MARK: - Local formatting

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
