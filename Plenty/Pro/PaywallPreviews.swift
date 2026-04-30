//
//  PaywallPreviews.swift
//  Plenty
//
//  Target path: Plenty/Pro/PaywallPreviews.swift
//
//  Phase 3.1 (post-launch v1): visual previews of the three Pro
//  modes — Outlook, Save, Trends — for use inside PaywallSheet.
//  Each preview is a small static card (~140pt tall) with hardcoded
//  fixture data and an "Example" badge so users can evaluate the
//  feature shape before deciding to unlock.
//
//  Why custom instead of reusing the live views:
//
//    • OutlookView, SaveView, and TrendsView all read from @Query
//      and compute against real models. Feeding them fixture data
//      requires either building synthetic @Model instances (which
//      is heavyweight and brittle) or refactoring to accept value-
//      type inputs (more invasive than the marketing surface
//      justifies).
//    • The full-size views are also too dense to read at preview
//      size — chart axes, multi-row breakdowns, and slider chrome
//      collapse poorly into 140pt-tall tiles.
//    • These previews are designed for the conversion surface, not
//      reused anywhere else, so visual drift from the live views
//      is contained.
//
//  Trade-off: if the live views change visual style, these previews
//  need a manual update. Documented here so it's not a surprise.
//

import SwiftUI
import Charts

// MARK: - Public

/// One of the three Pro modes the paywall previews. Used to drive
/// title/description copy in PaywallSheet alongside the visual card.
enum PaywallPreviewKind: String, CaseIterable, Hashable, Identifiable {
    case outlook
    case save
    case trends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outlook: return "Outlook"
        case .save:    return "Save"
        case .trends:  return "Trends"
        }
    }

    var description: String {
        switch self {
        case .outlook: return "Twelve months projected from your real data, so you can see when you'll be flush and when you'll be tight."
        case .save:    return "Set savings goals and pay down debt with avalanche or snowball strategies. Plenty does the math."
        case .trends:  return "Six months of net worth and a clear breakdown of where your money goes by category."
        }
    }
}

/// Routes a kind to its visual preview. Used by PaywallSheet to
/// stack three previews in a column.
struct PaywallPreviewCard: View {
    let kind: PaywallPreviewKind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            previewHeader

            visual
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .overlay(alignment: .topTrailing) {
            exampleBadge
                .padding(12)
        }
    }

    private var previewHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.primary)
                Text(kind.description)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
    }

    private var iconName: String {
        switch kind {
        case .outlook: return "calendar"
        case .save:    return "leaf"
        case .trends:  return "chart.bar"
        }
    }

    private var exampleBadge: some View {
        Text("Example")
            .font(Typography.Support.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(Theme.Opacity.soft))
            )
    }

    @ViewBuilder
    private var visual: some View {
        switch kind {
        case .outlook: OutlookPreviewVisual()
        case .save:    SavePreviewVisual()
        case .trends:  TrendsPreviewVisual()
        }
    }
}

// MARK: - Outlook Preview

/// 12-month projected ending cash, mirroring OutlookChart's sage
/// area + line treatment. Includes one negative month to surface
/// the terracotta highlight — that's the key story the live chart
/// tells, so previewing it sells the feature honestly.
private struct OutlookPreviewVisual: View {

    private let points: [OutlookPoint] = [
        .init(label: "Apr", value: 3500),
        .init(label: "May", value: 4200),
        .init(label: "Jun", value: 4800),
        .init(label: "Jul", value: 3200),
        .init(label: "Aug", value: 1400),
        .init(label: "Sep", value: 800),
        .init(label: "Oct", value: -200),  // negative dip
        .init(label: "Nov", value: 1500),
        .init(label: "Dec", value: 2800),
        .init(label: "Jan", value: 3400),
        .init(label: "Feb", value: 4100),
        .init(label: "Mar", value: 4800)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(points) { point in
                AreaMark(
                    x: .value("Month", point.label),
                    y: .value("Cash", point.value)
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
                    x: .value("Month", point.label),
                    y: .value("Cash", point.value)
                )
                .foregroundStyle(Theme.sage)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                if point.value < 0 {
                    PointMark(
                        x: .value("Month", point.label),
                        y: .value("Cash", point.value)
                    )
                    .foregroundStyle(Theme.terracotta)
                    .symbolSize(48)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plot in
                plot.padding(.horizontal, 0)
            }
            .frame(height: 80)

            HStack {
                Text("Apr")
                    .font(Typography.Support.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Oct dips below zero")
                    .font(Typography.Support.caption)
                    .foregroundStyle(Theme.terracotta)
                Spacer()
                Text("Mar")
                    .font(Typography.Support.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private struct OutlookPoint: Identifiable {
        let label: String
        let value: Double
        var id: String { label }
    }
}

// MARK: - Save Preview

/// Two compact cards side by side: a savings goal progress arc and
/// a debt-payoff timeline. Captures Save mode's two pillars without
/// reproducing the full layout.
private struct SavePreviewVisual: View {

    var body: some View {
        HStack(spacing: 12) {
            goalCard
            debtCard
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Theme.sage.opacity(Theme.Opacity.soft), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: 0.62)
                    .stroke(Theme.sage, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("62%")
                        .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("of $5k")
                        .font(Typography.Support.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text("House fund")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.primary)
                Text("$3,100 saved")
                    .font(Typography.Support.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                .fill(Theme.sage.opacity(Theme.Opacity.soft))
        )
    }

    private var debtCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Avalanche")
                .font(Typography.Support.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            Text("18 mo")
                .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)

            Text("to debt-free")
                .font(Typography.Support.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                ForEach(0..<6) { i in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(i < 2 ? Theme.sage : Theme.sage.opacity(Theme.Opacity.soft))
                        .frame(height: 4)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                .fill(Theme.cardSurface)
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Trends Preview

/// Net-worth sparkline + a three-row spending breakdown — the two
/// visual stories TrendsView leads with.
private struct TrendsPreviewVisual: View {

    private let netWorthPoints: [NetWorthPoint] = [
        .init(month: "Nov", value: 28_400),
        .init(month: "Dec", value: 29_100),
        .init(month: "Jan", value: 30_800),
        .init(month: "Feb", value: 32_200),
        .init(month: "Mar", value: 34_500),
        .init(month: "Apr", value: 36_900)
    ]

    private let spendingRows: [SpendingRow] = [
        .init(category: "Groceries",      amount: 540, fraction: 1.00),
        .init(category: "Dining",         amount: 320, fraction: 0.59),
        .init(category: "Transportation", amount: 210, fraction: 0.39)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            netWorthRow
            Divider()
            spendingList
        }
    }

    private var netWorthRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Net Worth")
                    .font(Typography.Support.caption)
                    .foregroundStyle(.secondary)
                Text("$36,900")
                    .font(Typography.Body.emphasis.monospacedDigit())
                    .foregroundStyle(.primary)
                Text("+$8,500 in 6 mo")
                    .font(Typography.Support.caption)
                    .foregroundStyle(Theme.sage)
            }

            Chart(netWorthPoints) { point in
                LineMark(
                    x: .value("Month", point.month),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Theme.sage)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Month", point.month),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.sage.opacity(0.3), Theme.sage.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
        }
    }

    private var spendingList: some View {
        VStack(spacing: 6) {
            ForEach(spendingRows) { row in
                HStack(spacing: 8) {
                    Text(row.category)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.primary)
                        .frame(width: 100, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(Theme.Opacity.hairline))
                                .frame(height: 6)

                            Capsule()
                                .fill(Theme.sage)
                                .frame(width: geo.size.width * row.fraction, height: 6)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 6)

                    Text("$\(Int(row.amount))")
                        .font(Typography.Support.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private struct NetWorthPoint: Identifiable {
        let month: String
        let value: Double
        var id: String { month }
    }

    private struct SpendingRow: Identifiable {
        let category: String
        let amount: Double
        let fraction: Double
        var id: String { category }
    }
}

// MARK: - Preview

#Preview("Outlook") {
    PaywallPreviewCard(kind: .outlook)
        .padding()
        .background(Theme.background)
}

#Preview("Save") {
    PaywallPreviewCard(kind: .save)
        .padding()
        .background(Theme.background)
}

#Preview("Trends") {
    PaywallPreviewCard(kind: .trends)
        .padding()
        .background(Theme.background)
}

#Preview("All Three") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(PaywallPreviewKind.allCases) { kind in
                PaywallPreviewCard(kind: kind)
            }
        }
        .padding()
    }
    .background(Theme.background)
}
