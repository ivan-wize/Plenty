//
//  IncomeMonthSummaryCard.swift
//  Plenty
//
//  Target path: Plenty/Features/Income/IncomeMonthSummaryCard.swift
//
//  Phase 4 (v2): the header card at the top of the Income tab.
//
//  Two columns, divider in between:
//
//      ┌─────────────────────────────────────────┐
//      │  CONFIRMED              EXPECTED         │
//      │  $2,400                 $2,400           │
//      │  1 paycheck             1 paycheck       │
//      └─────────────────────────────────────────┘
//
//  Numbers go sage-toned to match positive-currency convention; the
//  whole card is restrained — no progress bar, no pie chart, just
//  legible totals. Voice for the count line follows PDS §13: plain,
//  possession-leading, no exclamations.
//

import SwiftUI

struct IncomeMonthSummaryCard: View {

    let confirmedTotal: Decimal
    let confirmedCount: Int
    let expectedTotal: Decimal
    let expectedCount: Int

    var body: some View {
        HStack(spacing: 0) {
            column(
                label: "Confirmed",
                amount: confirmedTotal,
                count: confirmedCount,
                isMuted: confirmedTotal == 0
            )

            Divider()
                .frame(height: 56)

            column(
                label: "Expected",
                amount: expectedTotal,
                count: expectedCount,
                isMuted: expectedTotal == 0
            )
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func column(
        label: String,
        amount: Decimal,
        count: Int,
        isMuted: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(Typography.Support.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Text(amount.asPlainCurrency())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isMuted ? .secondary : Theme.sage)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(countLabel(count: count))
                .font(Typography.Support.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func countLabel(count: Int) -> String {
        switch count {
        case 0:  return "Nothing yet"
        case 1:  return "1 entry"
        default: return "\(count) entries"
        }
    }

    private var accessibilityLabel: String {
        let confirmedAmount = confirmedTotal.asPlainCurrency()
        let expectedAmount = expectedTotal.asPlainCurrency()
        return "Confirmed \(confirmedAmount). Expected \(expectedAmount)."
    }
}

// MARK: - Decimal Helper

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
