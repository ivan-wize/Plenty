//
//  NetWorthChartView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/NetWorthChartView.swift
//
//  Configurable net worth chart for the detail screen. Differs from
//  NetWorthTrendChart (the 6-month card on Trends) by exposing a
//  timeframe selector and stacking assets / debt as separate series.
//
//  The chart shows three lines:
//    • Net Worth (sage, primary line)
//    • Assets    (sage tint, secondary)
//    • Debt      (terracotta tint, secondary)
//
//  Empty state renders when fewer than two history points are
//  available — needs at least two to draw a line.
//

import SwiftUI
import Charts

struct NetWorthChartView: View {

    let accounts: [Account]
    @Binding var timeframe: NetWorthInsightEngine.Timeframe

    private var points: [NetWorthInsightEngine.HistoryPoint] {
        NetWorthInsightEngine.historyPoints(accounts: accounts, timeframe: timeframe)
    }

    private var hasEnoughData: Bool { points.count >= 2 }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            timeframeSelector

            if hasEnoughData {
                chart
                    .frame(height: 220)

                legend
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

    // MARK: - Timeframe Selector

    private var timeframeSelector: some View {
        Picker("Timeframe", selection: $timeframe) {
            ForEach(NetWorthInsightEngine.Timeframe.allCases) { frame in
                Text(frame.displayName).tag(frame)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(points) { point in

            // Net worth — primary line.
            LineMark(
                x: .value("Date", point.bucketEnd),
                y: .value("Net Worth", asDouble(point.netWorth)),
                series: .value("Series", "Net Worth")
            )
            .foregroundStyle(Theme.sage)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.monotone)

            AreaMark(
                x: .value("Date", point.bucketEnd),
                y: .value("Net Worth", asDouble(point.netWorth)),
                series: .value("Series", "Net Worth")
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.sage.opacity(0.25), Theme.sage.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            // Assets — secondary line.
            LineMark(
                x: .value("Date", point.bucketEnd),
                y: .value("Assets", asDouble(point.assets)),
                series: .value("Series", "Assets")
            )
            .foregroundStyle(Theme.sage.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            .interpolationMethod(.monotone)

            // Debt — secondary line, terracotta.
            LineMark(
                x: .value("Date", point.bucketEnd),
                y: .value("Debt", asDouble(point.debt)),
                series: .value("Series", "Debt")
            )
            .foregroundStyle(Theme.terracotta.opacity(0.7))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            .interpolationMethod(.monotone)
        }
        .chartLegend(.hidden)
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
            AxisMarks(values: .stride(by: xAxisStride)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var xAxisStride: Calendar.Component {
        switch timeframe {
        case .threeMonths: return .month
        case .sixMonths:   return .month
        case .oneYear:     return .month
        case .allTime:     return points.count > 18 ? .year : .month
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Theme.sage,                   label: "Net worth", solid: true)
            legendItem(color: Theme.sage.opacity(0.7),      label: "Assets",    solid: false)
            legendItem(color: Theme.terracotta.opacity(0.7), label: "Debt",      solid: false)
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String, solid: Bool) -> some View {
        HStack(spacing: 6) {
            if solid {
                Capsule().fill(color).frame(width: 16, height: 3)
            } else {
                HStack(spacing: 2) {
                    Capsule().fill(color).frame(width: 4, height: 2)
                    Capsule().fill(color).frame(width: 4, height: 2)
                    Capsule().fill(color).frame(width: 4, height: 2)
                }
                .frame(width: 16)
            }
            Text(label)
                .font(Typography.Support.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not enough history")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)

            Text("Plenty draws this from your account balance updates. Update your balances each month to build the picture.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func asDouble(_ d: Decimal) -> Double {
        NSDecimalNumber(decimal: d).doubleValue
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
