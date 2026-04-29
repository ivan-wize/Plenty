//
//  MediumBudgetWidget.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/MediumBudgetWidget.swift
//
//  Build fix: added a fileprivate `Decimal.asCompactCurrency()` extension
//  at the bottom of this file. Same reasoning as SmallBudgetWidget —
//  the widget extension target doesn't link the main app's
//  Decimal+Currency helper.
//
//  Phase 8 (v2): renamed from MediumSpendableWidget. Two columns:
//
//    Left:  Plenty wordmark, big monthlyBudgetRemaining number,
//           "Left this month" or "Over budget" caption,
//           sustainable per-day burn (positive case).
//    Right: cash on hand, bills remaining count + total,
//           next income date.
//
//  No progress bar, no decoration. The number is the design.
//

import SwiftUI
import WidgetKit

struct MediumBudgetWidget: View {

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
        HStack(alignment: .top, spacing: 0) {
            heroColumn
                .frame(maxWidth: .infinity, alignment: .leading)
            contextColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hero

    private var heroColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            wordmark

            Spacer(minLength: 4)

            Text(formattedAmount)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(captionText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if let burn = entry.sustainableDailyBurn,
               burn > 0,
               !entry.isOverBudget {
                Text("~\(burn.asCompactCurrency())/day")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Context Column

    private var contextColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            contextRow(
                icon: "banknote",
                label: "Cash",
                value: entry.cashOnHand.asCompactCurrency()
            )

            if entry.billsRemainingCount > 0 {
                contextRow(
                    icon: "doc.text",
                    label: "\(entry.billsRemainingCount) bill\(entry.billsRemainingCount == 1 ? "" : "s")",
                    value: entry.billsRemaining.asCompactCurrency()
                )
            } else if let name = entry.nextBillName {
                contextRow(
                    icon: "doc.text",
                    label: "Next: \(name)",
                    value: entry.nextBillAmount?.asCompactCurrency() ?? ""
                )
            }

            if let nextIncome = entry.nextIncomeDate {
                contextRow(
                    icon: "arrow.down.circle",
                    label: "Income",
                    value: shortDate(nextIncome)
                )
            }
        }
        .padding(.top, 18)
    }

    private func contextRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(value)
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    // MARK: - Unavailable / Empty

    private var unavailableView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                wordmark
                Spacer()
                Image(systemName: "icloud.slash")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.amber)
                Text("Open Plenty to refresh")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                wordmark
                Spacer()
                Text("Set up Plenty")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("to see your number")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
        entry.isOverBudget ? "Over budget" : "Left this month"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
