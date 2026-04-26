//
//  AccountRowView.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/AccountRowView.swift
//
//  Single row for an account. Used in AccountsListView. Shows:
//    • Category icon
//    • Account name
//    • Current balance (with leading minus for liabilities)
//    • Freshness indicator (e.g., "Updated 7d ago" in muted text;
//      amber if ≥ 14 days)
//

import SwiftUI

struct AccountRowView: View {

    let account: Account

    var body: some View {
        HStack(spacing: 14) {
            iconCircle

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(freshnessText)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(freshnessColor)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedBalance)
                    .font(Typography.Body.emphasis.monospacedDigit())
                    .foregroundStyle(account.isAsset ? .primary : Theme.terracotta)
                    .lineLimit(1)

                if let secondary = secondaryLine {
                    Text(secondary)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Icon

    private var iconCircle: some View {
        Image(systemName: account.category.iconName)
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.sage)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 38, height: 38)
            .background(
                Circle().fill(Theme.sage.opacity(Theme.Opacity.soft))
            )
    }

    // MARK: - Formatting

    private var formattedBalance: String {
        let formatted = account.balance.asPlainCurrency()
        return account.isAsset ? formatted : "−\(formatted)"
    }

    private var freshnessText: String {
        let days = account.daysSinceBalanceUpdate
        if days == 0 { return "Updated today" }
        if days == 1 { return "Updated yesterday" }
        return "Updated \(days)d ago"
    }

    /// Amber when balance is ≥ 14 days stale; otherwise secondary.
    private var freshnessColor: Color {
        account.daysSinceBalanceUpdate >= 14 ? Theme.amber : .secondary
    }

    /// Optional second line under the balance: utilization for credit
    /// cards, APR for loans, nothing otherwise.
    private var secondaryLine: String? {
        switch account.kind {
        case .credit:
            if let limit = account.creditLimitOrOriginalBalance, limit > 0,
               let util = account.utilization {
                let pct = Int((util * 100).rounded())
                return "\(pct)% of \(limit.asPlainCurrency()) limit"
            }
            if let apr = account.interestRate, apr > 0 {
                return String(format: "%.2f%% APR", (apr as NSDecimalNumber).doubleValue)
            }
            return nil
        case .loan:
            if let apr = account.interestRate, apr > 0 {
                return String(format: "%.2f%% APR", (apr as NSDecimalNumber).doubleValue)
            }
            return nil
        case .cash, .investment:
            return nil
        }
    }

    private var accessibilityLabel: String {
        let balance = account.balance.asPlainCurrency()
        let signed = account.isAsset ? balance : "negative \(balance)"
        return "\(account.name), \(account.category.displayName), \(signed). \(freshnessText)."
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
