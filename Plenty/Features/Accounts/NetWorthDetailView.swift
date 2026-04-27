//
//  NetWorthDetailView.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/NetWorthDetailView.swift
//
//  Pro-only full-screen detail for net worth. Pushed from
//  NetWorthSummaryCard via a NavigationLink.
//
//  Sections, top to bottom:
//    1. Hero — current net worth (large), assets and debt
//    2. Chart with timeframe selector (3M / 6M / 1Y / All)
//    3. Insights (0–3 plain-language statements)
//    4. Account breakdown — every account grouped by kind, signed
//
//  PRD §9.10 calls this out as a Pro feature. The view assumes the
//  caller has already gated on `appState.isProUnlocked`; the back
//  navigation handles the locked case.
//

import SwiftUI
import SwiftData

struct NetWorthDetailView: View {

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    @State private var timeframe: NetWorthInsightEngine.Timeframe = .sixMonths

    private var netWorth: Decimal { AccountDerivations.netWorth(allAccounts) }
    private var assets:   Decimal { AccountDerivations.totalAssets(allAccounts) }
    private var debt:     Decimal { AccountDerivations.totalDebt(allAccounts) }

    private var historyPoints: [NetWorthInsightEngine.HistoryPoint] {
        NetWorthInsightEngine.historyPoints(accounts: allAccounts, timeframe: timeframe)
    }

    private var insights: [NetWorthInsightEngine.Insight] {
        NetWorthInsightEngine.insights(from: historyPoints)
    }

    private var groupedAccounts: [(kind: AccountCategory.Kind, accounts: [Account])] {
        let active = AccountDerivations.activeAccounts(allAccounts)
        let byKind = Dictionary(grouping: active) { $0.kind }
        let order: [AccountCategory.Kind] = [.cash, .investment, .credit, .loan]
        return order.compactMap { kind in
            guard let group = byKind[kind], !group.isEmpty else { return nil }
            return (kind, group.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                    .padding(.horizontal, 16)

                NetWorthChartView(accounts: allAccounts, timeframe: $timeframe)
                    .padding(.horizontal, 16)

                if !insights.isEmpty {
                    insightsSection
                        .padding(.horizontal, 16)
                }

                breakdownSection
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Net Worth")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Net Worth")
                    .font(Typography.Support.label)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(formattedNetWorth)
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(netWorth >= 0 ? .primary : Theme.terracotta)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            HStack(spacing: 32) {
                miniStat(label: "Assets", value: assets, color: .primary)
                miniStat(label: "Debt",   value: debt,   color: Theme.terracotta)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private func miniStat(label: String, value: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
            Text(value.asPlainCurrency())
                .font(Typography.Body.emphasis.monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private var formattedNetWorth: String {
        let abs = netWorth < 0 ? -netWorth : netWorth
        let formatted = abs.asPlainCurrency()
        return netWorth < 0 ? "−\(formatted)" : formatted
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's changed")
                .font(Typography.Title.small)

            VStack(spacing: 8) {
                ForEach(insights) { insight in
                    insightRow(insight)
                }
            }
        }
    }

    private func insightRow(_ insight: NetWorthInsightEngine.Insight) -> some View {
        let tint: Color = {
            switch insight.kind {
            case .growth:  return Theme.sage
            case .decline: return Theme.terracotta
            case .neutral: return .secondary
            }
        }()
        let icon: String = {
            switch insight.kind {
            case .growth:  return "arrow.up.right"
            case .decline: return "arrow.down.right"
            case .neutral: return "circle.fill"
            }
        }()

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(Theme.Opacity.soft)))

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(Typography.Body.emphasis)
                Text(insight.detail)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account breakdown")
                .font(Typography.Title.small)

            VStack(spacing: 12) {
                ForEach(groupedAccounts, id: \.kind) { group in
                    breakdownGroup(kind: group.kind, accounts: group.accounts)
                }
            }
        }
    }

    private func breakdownGroup(kind: AccountCategory.Kind, accounts: [Account]) -> some View {
        let groupTotal = accounts.reduce(Decimal.zero) { $0 + $1.balance }
        let isAsset = kind != .credit && kind != .loan

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(kind.pluralDisplayName)
                    .font(Typography.Body.emphasis)
                Spacer()
                Text("\(isAsset ? "" : "−")\(groupTotal.asPlainCurrency())")
                    .font(Typography.Body.emphasis.monospacedDigit())
                    .foregroundStyle(isAsset ? .primary : Theme.terracotta)
            }
            Divider()
            VStack(spacing: 6) {
                ForEach(accounts) { account in
                    breakdownRow(account: account)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private func breakdownRow(account: Account) -> some View {
        HStack {
            Image(systemName: account.category.iconName)
                .font(.body)
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24)

            Text(account.name)
                .font(Typography.Body.regular)

            Spacer()

            Text("\(account.isAsset ? "" : "−")\(account.balance.asPlainCurrency())")
                .font(Typography.Currency.row.monospacedDigit())
                .foregroundStyle(account.isAsset ? .primary : Theme.terracotta)
        }
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
