//
//  AccountsTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/AccountsTab.swift
//
//  The Accounts tab. Layout:
//
//    [ NetWorthSummaryCard ]
//
//    Accounts (grouped by kind, navigates to AccountDetailView)
//
//    Bills          → BillsListView
//    Transactions   → TransactionsListView
//    Subscriptions  → SubscriptionsListView
//
//  Replaces the Phase 2 stub. NavigationStack hosts the destinations
//  so deep navigation pops cleanly when the user switches tabs.
//

import SwiftUI
import SwiftData

struct AccountsTab: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]
    @Query private var allTransactions: [Transaction]
    @Query private var allSubscriptions: [Subscription]

    private var activeAccounts: [Account] {
        AccountDerivations.activeAccounts(allAccounts)
    }

    private var billsThisMonth: Int {
        let cal = Calendar.current
        let m = cal.component(.month, from: .now)
        let y = cal.component(.year, from: .now)
        return TransactionProjections.bills(allTransactions, month: m, year: y).count
    }

    private var transactionsCount: Int {
        allTransactions.filter { $0.kind != .bill }.count
    }

    private var subscriptionsCount: Int {
        allSubscriptions.filter { $0.state == .confirmed }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    NetWorthSummaryCard(accounts: activeAccounts)

                    accountsSection

                    listsSection
                }
                .padding(.vertical, 16)
            }
            .background(Theme.background)
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        NavigationLink {
            AccountsListView()
        } label: {
            sectionRow(
                icon: "creditcard.and.123",
                title: "Accounts",
                subtitle: accountsSubtitle,
                trailing: nil
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var accountsSubtitle: String {
        let count = activeAccounts.count
        if count == 0 { return "Add your first account" }
        if count == 1 { return "1 account" }
        return "\(count) accounts"
    }

    // MARK: - Lists Section

    private var listsSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                BillsListView()
            } label: {
                sectionRow(
                    icon: "doc.text",
                    title: "Bills",
                    subtitle: billsThisMonth == 0 ? "None this month" : "\(billsThisMonth) this month",
                    trailing: nil
                )
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                TransactionsListView()
            } label: {
                sectionRow(
                    icon: "list.bullet",
                    title: "Transactions",
                    subtitle: transactionsCount == 0 ? "None yet" : "\(transactionsCount) total",
                    trailing: nil
                )
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                SubscriptionsListView()
            } label: {
                sectionRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Subscriptions",
                    subtitle: subscriptionsCount == 0 ? "None tracked" : "\(subscriptionsCount) tracked",
                    trailing: nil
                )
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Row Helper

    private func sectionRow(
        icon: String,
        title: String,
        subtitle: String,
        trailing: String?
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.Body.regular)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(Typography.Body.emphasis.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(Theme.Opacity.hairline))
            .frame(height: 0.5)
            .padding(.leading, 66)
    }
}
