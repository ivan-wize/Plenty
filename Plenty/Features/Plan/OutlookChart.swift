//
//  OutlookChart.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/OutlookChart.swift
//
//  Swift Charts visualization of 12-month projected ending cash.
//  Area chart with sage fill. Terracotta highlight on any month where
//  projected ending cash dips below zero (a future cash crunch).
//

import SwiftUI
import Charts

struct OutlookChart: View {

    let months: [OutlookEngine.Month]

    private var lowestMonth: OutlookEngine.Month? {
        months.min(by: { $0.projectedEndingCash < $1.projectedEndingCash })
    }

    private var hasNegativeMonth: Bool {
        months.contains { $0.projectedEndingCash < 0 }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chart
                .frame(height: 200)

            if hasNegativeMonth, let lowest = lowestMonth {
                lowestCallout(lowest)
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(months) { month in
            AreaMark(
                x: .value("Month", month.label),
                y: .value("Ending Cash", (month.projectedEndingCash as NSDecimalNumber).doubleValue)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.sage.opacity(0.4), Theme.sage.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Month", month.label),
                y: .value("Ending Cash", (month.projectedEndingCash as NSDecimalNumber).doubleValue)
            )
            .foregroundStyle(Theme.sage)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))

            if month.projectedEndingCash < 0 {
                PointMark(
                    x: .value("Month", month.label),
                    y: .value("Ending Cash", (month.projectedEndingCash as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(Theme.terracotta)
                .symbolSize(64)
            }
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
            AxisMarks(values: .stride(by: 1)) { value in
                AxisValueLabel(centered: true)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Callout

    private func lowestCallout(_ month: OutlookEngine.Month) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.body)
                .foregroundStyle(Theme.terracotta)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tightest projected month: \(month.label) \(String(month.year))")
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.primary)

                let absAmount = (month.projectedEndingCash < 0 ? -month.projectedEndingCash : month.projectedEndingCash).asPlainCurrency()
                Text("Cash projected at \(month.projectedEndingCash < 0 ? "−\(absAmount)" : absAmount). Worth a closer look.")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                .fill(Theme.terracotta.opacity(Theme.Opacity.soft))
        )
    }
}

// MARK: - Helpers

private extension Double {
    /// Compact currency: $1.2k, $34k, $1.5M.
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
