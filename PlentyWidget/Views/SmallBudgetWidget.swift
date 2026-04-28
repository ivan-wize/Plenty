//
//  SmallSpendableWidget.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/SmallSpendableWidget.swift
//
//  Home screen small widget. The most-installed family for this app.
//
//  Layout (vertical):
//    Plenty wordmark (small, top)
//    Spacer
//    Hero number (rounded bold, monospaced digit, zone color)
//    "Spendable" caption
//    Optional sub-line: per-day burn or upcoming bill summary
//

import SwiftUI
import WidgetKit

struct SmallSpendableWidget: View {

    let entry: PlentyEntry

    var body: some View {
        if entry.isUnavailable {
            unavailableView
        } else if !entry.hasAnyData {
            emptyView
        } else {
            contentView
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            wordmark

            Spacer(minLength: 4)

            Text(formattedAmount)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("Spendable")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            if let subline = subLineText {
                Text(subline)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Unavailable

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 8) {
            wordmark
            Spacer()
            Image(systemName: "icloud.slash")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.amber)
            Text("Open the app")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
            Text("to refresh")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            wordmark
            Spacer()
            Text("Set up Plenty")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("to see your number")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        HStack(spacing: 0) {
            Text("Plenty")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed

    private var formattedAmount: String {
        let abs = entry.spendable < 0 ? -entry.spendable : entry.spendable
        let formatted = abs.asCompactCurrency()
        return entry.spendable < 0 ? "−\(formatted)" : formatted
    }

    private var numberColor: Color {
        switch entry.zone {
        case .empty:   return .secondary
        case .safe:    return .primary
        case .warning: return Theme.amber
        case .over:    return Theme.terracotta
        }
    }

    private var subLineText: String? {
        if entry.zone == .over {
            return "Over your margin"
        }
        if entry.billsRemainingCount > 0 {
            let plural = entry.billsRemainingCount == 1 ? "bill" : "bills"
            return "\(entry.billsRemainingCount) \(plural) due"
        }
        if let burn = entry.sustainableDailyBurn, burn > 0 {
            return "~\(burn.asCompactCurrency())/day"
        }
        return nil
    }
}

private extension Decimal {
    func asCompactCurrency() -> String {
        let value = NSDecimalNumber(decimal: self).doubleValue
        let absValue = abs(value)
        if absValue >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        }
        if absValue >= 10_000 {
            return String(format: "$%.0fk", value / 1_000)
        }
        if absValue >= 1_000 {
            return String(format: "$%.1fk", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }
}
