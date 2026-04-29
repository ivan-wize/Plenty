//
//  SmallBudgetWidget.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/SmallBudgetWidget.swift
//
//  Build fix: added a fileprivate `Decimal.asCompactCurrency()` extension
//  at the bottom of this file. The widget extension target doesn't
//  link `Plenty/Utilities/Decimal+Currency.swift` — that file is in the
//  main app target only. Either add it to the widget target's Compile
//  Sources, or keep these fileprivate copies. Both work; the latter is
//  zero-touch on the project file.
//
//  Phase 8 (v2): renamed from SmallSpendableWidget. Reads the v2 hero
//  number (`monthlyBudgetRemaining`). Color and caption switch on
//  sign:
//
//    ≥ 0  →  sage number, "Left" caption
//    < 0  →  terracotta number, "Over" caption
//
//  The most-installed widget family for this app. Vertical layout:
//
//    Plenty wordmark (small, top)
//    Spacer
//    Hero number (rounded bold, monospaced digit)
//    "Left" / "Over" caption
//    Optional sub-line: per-day burn or upcoming bill summary
//

import SwiftUI
import WidgetKit

struct SmallBudgetWidget: View {

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

            Text(captionText)
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
        Text("Plenty")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
    }

    // MARK: - Computed

    private var formattedAmount: String {
        let abs = entry.monthlyBudgetRemaining < 0
            ? -entry.monthlyBudgetRemaining
            : entry.monthlyBudgetRemaining
        let value = NSDecimalNumber(decimal: abs).doubleValue
        let formatted: String
        if value >= 1_000_000 {
            formatted = String(format: "$%.1fM", value / 1_000_000)
        } else if value >= 10_000 {
            formatted = String(format: "$%.0fk", value / 1_000)
        } else if value >= 1_000 {
            formatted = String(format: "$%.1fk", value / 1_000)
        } else {
            formatted = String(format: "$%.0f", value)
        }
        return entry.isOverBudget ? "−\(formatted)" : formatted
    }

    private var numberColor: Color {
        entry.isOverBudget ? Theme.terracotta : Theme.sage
    }

    private var captionText: String {
        entry.isOverBudget ? "Over" : "Left"
    }

    private var subLineText: String? {
        // Prefer per-day burn when available and not over budget.
        if !entry.isOverBudget,
           let burn = entry.sustainableDailyBurn,
           burn > 0 {
            return "~\(burn.asCompactCurrency())/day"
        }

        // Fall back to next bill summary.
        if let name = entry.nextBillName,
           let amount = entry.nextBillAmount,
           let day = entry.nextBillDueDay {
            return "\(name) \(day.ordinalString): \(amount.asCompactCurrency())"
        }

        return nil
    }
}

// MARK: - Decimal Helper

/// Local copy of the compact-currency formatter so this file compiles
/// inside the widget target without depending on
/// `Plenty/Utilities/Decimal+Currency.swift`. Output matches the main
/// app's compact form: $1.5k, $250, $1.2M.
fileprivate extension Decimal {
    func asCompactCurrency() -> String {
        let value = NSDecimalNumber(decimal: self).doubleValue
        let absValue = abs(value)
        let formatted: String
        if absValue >= 1_000_000 {
            formatted = String(format: "$%.1fM", absValue / 1_000_000)
        } else if absValue >= 10_000 {
            formatted = String(format: "$%.0fk", absValue / 1_000)
        } else if absValue >= 1_000 {
            formatted = String(format: "$%.1fk", absValue / 1_000)
        } else {
            formatted = String(format: "$%.0f", absValue)
        }
        return value < 0 ? "−\(formatted)" : formatted
    }
}
