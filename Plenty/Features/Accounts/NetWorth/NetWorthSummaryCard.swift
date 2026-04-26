//
//  NetWorthSummaryCard.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/NetWorthSummaryCard.swift
//
//  Headline card at the top of AccountsTab. Three lines: net worth
//  (large), total assets, total debt. Compact, no chart in Phase 5
//  (Phase 6 brings a 6-month trend chart on the Plan tab).
//

import SwiftUI

struct NetWorthSummaryCard: View {

    let accounts: [Account]

    private var netWorth: Decimal {
        AccountDerivations.netWorth(accounts)
    }

    private var assets: Decimal {
        AccountDerivations.totalAssets(accounts)
    }

    private var debt: Decimal {
        AccountDerivations.totalDebt(accounts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Net Worth")
                    .font(Typography.Support.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(formattedNetWorth)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(netWorth >= 0 ? .primary : Theme.terracotta)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            HStack(spacing: 32) {
                stat(label: "Assets", value: assets, color: .primary)
                stat(label: "Debt", value: debt, color: Theme.terracotta)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Stat

    private func stat(label: String, value: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
            Text(value.asPlainCurrency())
                .font(Typography.Body.emphasis.monospacedDigit())
                .foregroundStyle(color)
        }
    }

    // MARK: - Formatting

    private var formattedNetWorth: String {
        let abs = netWorth < 0 ? -netWorth : netWorth
        let formatted = abs.asPlainCurrency()
        return netWorth < 0 ? "−\(formatted)" : formatted
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
