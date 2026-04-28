//
//  MediumSpendableWidget.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/MediumSpendableWidget.swift
//
//  Home screen medium widget. Two columns:
//
//    Left: hero (Plenty wordmark, big number, "Spendable" caption,
//                sustainable per-day burn)
//    Right: context (cash on hand, bills remaining count + total,
//                    next income date)
//
//  No progress bar, no decoration. The number is the design.
//

import SwiftUI
import WidgetKit

struct MediumSpendableWidget: View {

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

            Text("Spendable")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if let burn = entry.sustainableDailyBurn, burn > 0, entry.zone != .over {
                Text("~\(burn.asCompactCurrency())/day")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if entry.zone == .over {
                Text("Over your margin")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.terracotta)
            }
        }
    }

    // MARK: - Context

    private var contextColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            statLine(
                label: "Cash on hand",
                value: entry.cashOnHand.asCompactCurrency(),
                color: .primary
            )

            if entry.billsRemainingCount > 0 {
                statLine(
                    label: "Bills due",
                    value: "\(entry.billsRemainingCount) · \(entry.billsRemaining.asCompactCurrency())",
                    color: .primary
                )
            } else if entry.billsRemaining == 0 {
                statLine(
                    label: "Bills",
                    value: "All paid",
                    color: Theme.sage
                )
            }

            if let nextDate = entry.nextIncomeDate {
                statLine(
                    label: "Next income",
                    value: relativeDate(nextDate),
                    color: .primary
                )
            }
        }
    }

    private func statLine(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    // MARK: - Unavailable / Empty

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 8) {
            wordmark
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "icloud.slash")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open the app")
                        .font(.caption.weight(.semibold))
                    Text("to refresh your number")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            wordmark
            Spacer()
            Text("Set up Plenty")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text("Add a paycheck and a bill to see your number.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        let now = Date.now
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0

        if days < 0 { return "Past due" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days <= 6 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
