//
//  RectangularLockScreenView.swift
//  Plenty
//
//  Target path: PlentyWidget/Views/RectangularLockScreenView.swift
//
//  Lock screen rectangular widget. Three lines:
//    Line 1: "Spendable" label (caption)
//    Line 2: hero number (rounded bold)
//    Line 3: contextual sub-line (next bill or per-day burn)
//
//  Also used as the watchOS accessoryRectangular complication —
//  the layout works identically on both surfaces.
//

import SwiftUI
import WidgetKit

struct RectangularLockScreenView: View {

    let entry: PlentyEntry

    var body: some View {
        if entry.isUnavailable {
            unavailableView
        } else {
            contentView
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Spendable")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text(formattedAmount)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subline = subLineText {
                Text(subline)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Unavailable

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Plenty")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text("Open the app")
                .font(.caption.weight(.semibold))
            Text("to refresh")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed

    private var formattedAmount: String {
        let abs = entry.spendable < 0 ? -entry.spendable : entry.spendable
        let formatted = abs.asPlainCurrency()
        return entry.spendable < 0 ? "−\(formatted)" : formatted
    }

    private var subLineText: String? {
        if entry.zone == .over { return "Over your margin" }
        if let billName = entry.nextBillName,
           let amount = entry.nextBillAmount,
           let dueDay = entry.nextBillDueDay {
            return "\(billName) \(amount.asPlainCurrency()) · \(dueDay.ordinalString)"
        }
        if let burn = entry.sustainableDailyBurn, burn > 0 {
            return "~\(burn.asPlainCurrency())/day"
        }
        return nil
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
