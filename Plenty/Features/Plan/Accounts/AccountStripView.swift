//
//  AccountStripView.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/AccountStripView.swift
//
//  Horizontal scroll of small account chips beneath the hero. One chip
//  per active account, sorted by sortOrder. Each chip shows the
//  account name and current balance. Liabilities show with a leading
//  minus and a soft terracotta tint on the amount.
//
//  Phase 4: chips are decorative; tap is a no-op. Phase 5 wires
//  navigation to AccountDetailView once it exists. Empty state
//  hidden — when the user has no accounts, this view renders nothing
//  and SetupChecklistView handles the prompt.
//

import SwiftUI

struct AccountStripView: View {

    let accounts: [Account]

    var body: some View {
        if accounts.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(accounts) { account in
                        chip(for: account)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollClipDisabled()  // shadows shouldn't clip
        }
    }

    // MARK: - Chip

    private func chip(for account: Account) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: account.category.iconName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(account.name)
                    .font(Typography.Support.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(formattedBalance(for: account))
                .font(Typography.Body.emphasis.monospacedDigit())
                .foregroundStyle(account.isAsset ? .primary : Theme.terracotta)
                .lineLimit(1)
        }
        .frame(minWidth: 110, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: account))
    }

    // MARK: - Formatting

    private func formattedBalance(for account: Account) -> String {
        let value = account.balance
        let formatted = value.asPlainCurrency()
        return account.isAsset ? formatted : "−\(formatted)"
    }

    private func accessibilityLabel(for account: Account) -> String {
        let balance = account.balance.asPlainCurrency()
        let signed = account.isAsset ? balance : "negative \(balance)"
        return "\(account.name), \(account.category.displayName), \(signed)"
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
