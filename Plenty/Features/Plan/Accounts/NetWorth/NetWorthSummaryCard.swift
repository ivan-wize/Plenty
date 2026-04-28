//
//  NetWorthSummaryCard.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/NetWorthSummaryCard.swift
//
//  Headline card at the top of AccountsTab. Three lines: net worth
//  (large), total assets, total debt.
//
//  Replaces the prior NetWorthSummaryCard. One change: when the user
//  has Pro, the card becomes a NavigationLink that pushes
//  NetWorthDetailView. When locked, it stays a static card so the
//  Pro paywall doesn't ambush from a casual glance.
//
//  The Pro gate is checked via AppState. The link is wrapped in a
//  ZStack with `.disabled(!isPro)` so the card layout stays identical
//  in both states; only the chevron and tap behavior change.
//

import SwiftUI

struct NetWorthSummaryCard: View {

    let accounts: [Account]

    @Environment(AppState.self) private var appState

    private var isPro: Bool { appState.isProUnlocked }

    private var netWorth: Decimal {
        AccountDerivations.netWorth(accounts)
    }

    private var assets: Decimal {
        AccountDerivations.totalAssets(accounts)
    }

    private var debt: Decimal {
        AccountDerivations.totalDebt(accounts)
    }

    // MARK: - Body

    var body: some View {
        if isPro {
            NavigationLink {
                NetWorthDetailView()
            } label: {
                cardBody(showsChevron: true)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        } else {
            cardBody(showsChevron: false)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Card

    private func cardBody(showsChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Worth")
                        .font(Typography.Support.label)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(formattedNetWorth)
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(netWorth >= 0 ? .primary : Theme.terracotta)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 6)
                }
            }

            HStack(spacing: 32) {
                stat(label: "Assets", value: assets, color: .primary)
                stat(label: "Debt",   value: debt,   color: Theme.terracotta)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
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

// MARK: - Local formatting

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
