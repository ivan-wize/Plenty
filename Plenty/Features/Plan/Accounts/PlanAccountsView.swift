//
//  PlanAccountsView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/Accounts/PlanAccountsView.swift
//
//  Phase 6 (v2): the Accounts mode of the Plan tab. Replaces v1's
//  standalone AccountsTab.
//
//  Composition:
//    1. NetWorthSummaryCard — net worth (large) + assets + debt.
//       Tap opens NetWorthDetailView when Pro is unlocked, static
//       card when locked (existing behavior preserved from v1).
//    2. Accounts list — grouped by kind (cash, savings, credit,
//       loan, investment, etc.). Tap a row opens AccountDetailView.
//       Empty state offers an "Add an account" CTA.
//    3. Subscriptions row — single navigation row to
//       SubscriptionsListView. Subscription suggestions surface here
//       too via SubscriptionSuggestionsView when applicable.
//
//  Bills and Transactions navigation rows from v1's AccountsTab are
//  removed in v2 — both surfaces live in the Expenses tab with their
//  own segmented control.
//

import SwiftUI
import SwiftData

struct PlanAccountsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]
    @Query private var allSubscriptions: [Subscription]
    @Query private var allTransactions: [Transaction]

    private var activeAccounts: [Account] {
        AccountDerivations.activeAccounts(allAccounts)
    }

    private var groupedAccounts: [(kind: AccountKind, accounts: [Account])] {
        AccountKind.allCases.compactMap { kind in
            let group = activeAccounts
                .filter { $0.kind == kind }
                .sorted { $0.sortOrder < $1.sortOrder }
            return group.isEmpty ? nil : (kind, group)
        }
    }

    private var trackedSubscriptionsCount: Int {
        allSubscriptions.filter { $0.state == .confirmed }.count
    }

    private var hasSubscriptionSuggestions: Bool {
        !allSubscriptions.contains { $0.state == .suggested }
            ? false
            : true
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NetWorthSummaryCard(accounts: activeAccounts)

                if activeAccounts.isEmpty {
                    emptyAccountsState
                } else {
                    accountsList
                }

                if hasSubscriptionSuggestions {
                    SubscriptionSuggestionsView()
                        .padding(.horizontal, 16)
                }

                subscriptionsRow

                Color.clear.frame(height: 60)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.background)
    }

    // MARK: - Empty Accounts

    private var emptyAccountsState: some View {
        VStack(spacing: 12) {
            ContentUnavailableView {
                Label("No accounts yet", systemImage: "creditcard")
                    .foregroundStyle(Theme.sage)
            } description: {
                Text("Add your checking, savings, and credit cards to see your real cash position.")
                    .multilineTextAlignment(.center)
            }

            Button {
                appState.pendingAddSheet = .account()
            } label: {
                HStack {
                    Spacer()
                    Text("Add an account")
                        .font(Typography.Body.emphasis)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.sage)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Accounts List

    private var accountsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accounts")
                    .font(Typography.Title.small)
                Spacer()
                Button {
                    appState.pendingAddSheet = .account()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.sage)
                }
                .accessibilityLabel("Add an account")
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(groupedAccounts.enumerated()), id: \.offset) { groupIndex, group in
                    if groupIndex > 0 {
                        sectionDivider(label: group.kind.pluralDisplayName)
                    } else {
                        sectionHeader(label: group.kind.pluralDisplayName)
                    }

                    ForEach(Array(group.accounts.enumerated()), id: \.element.id) { rowIndex, account in
                        NavigationLink {
                            AccountDetailView(account: account)
                        } label: {
                            AccountRowView(account: account)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if rowIndex < group.accounts.count - 1 {
                            rowDivider
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )
            .padding(.horizontal, 16)
        }
    }

    private func sectionHeader(label: String) -> some View {
        Text(label)
            .font(Typography.Support.label)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionDivider(label: String) -> some View {
        VStack(spacing: 0) {
            rowDivider
            sectionHeader(label: label)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(Theme.Opacity.hairline))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }

    // MARK: - Subscriptions

    private var subscriptionsRow: some View {
        NavigationLink {
            SubscriptionsListView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.sage)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Subscriptions")
                        .font(Typography.Body.regular)
                        .foregroundStyle(.primary)
                    Text(subscriptionsSubtitle)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var subscriptionsSubtitle: String {
        switch trackedSubscriptionsCount {
        case 0:  return "Plenty watches for recurring charges."
        case 1:  return "1 tracked"
        default: return "\(trackedSubscriptionsCount) tracked"
        }
    }
}
