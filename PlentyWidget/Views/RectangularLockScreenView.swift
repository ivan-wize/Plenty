//
//  RectangularLockScreenView.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/RectangularLockScreenView.swift
//
//  Phase 4.2 (post-launch v1): replaces the manual ternary plural for
//  "1 bill" / "N bills" with Automatic Grammar Agreement via
//  String(localized:) and the ^[…](inflect: true) syntax. iOS
//  pluralizes correctly per locale at runtime.
//
//  Build fix: added a fileprivate `Decimal.asCompactCurrency()` extension
//  at the bottom of this file. Same reasoning as SmallBudgetWidget —
//  the widget extension target doesn't link the main app's
//  Decimal+Currency helper.
//
//  Phase 8 (v2): three-line lock-screen widget. Reads
//  `monthlyBudgetRemaining` for the headline.
//
//  Layout:
//    Plenty                           ← wordmark (top, secondary)
//    $1,840 left                      ← number + state
//    ~$92/day or 2 bills $640         ← context line (optional)
//

import SwiftUI
import WidgetKit

struct RectangularLockScreenView: View {

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

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Plenty")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formattedAmount)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(stateText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let subline = subLineText {
                Text(subline)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Plenty")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Open the app")
                .font(.system(size: 13, weight: .semibold))
            Text("to refresh")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Plenty")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Set up to see your number")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        } else if value >= 1_000 {
            formatted = String(format: "$%.1fk", value / 1_000)
        } else {
            formatted = String(format: "$%.0f", value)
        }
        return entry.isOverBudget ? "−\(formatted)" : formatted
    }

    private var stateText: String {
        entry.isOverBudget ? "over" : "left"
    }

    private var subLineText: String? {
        if !entry.isOverBudget,
           let burn = entry.sustainableDailyBurn,
           burn > 0 {
            return "~\(burn.asCompactCurrency())/day"
        }
        if entry.billsRemainingCount > 0 {
            // Phase 4.2: use Automatic Grammar Agreement so "1 bill"
            // vs "2 bills" inflects correctly in every supported locale
            // without manual ternary plural logic. Xcode extracts the
            // ^[…](inflect: true) form into Localizable.xcstrings on
            // build and offers translators a plural variations editor.
            return String(
                localized: "^[\(entry.billsRemainingCount) bill](inflect: true) \(entry.billsRemaining.asCompactCurrency())",
                comment: "Lock-screen rectangular subline: count of unpaid bills + total amount remaining."
            )
        }
        return nil
    }
}

// MARK: - Decimal Helper

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
