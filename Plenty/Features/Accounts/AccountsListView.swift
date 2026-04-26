//
//  AccountsListView.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/AccountsListView.swift
//
//  Lists every active account, grouped by kind (Cash, Credit,
//  Investment, Loan). Tap an account to navigate to AccountDetailView.
//  Empty state nudges to add the first account.
//

import SwiftUI
import SwiftData

struct AccountsListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    private var activeAccounts: [Account] {
        AccountDerivations.activeAccounts(allAccounts)
    }

    private var groupedAccounts: [(kind: AccountCategory.Kind, accounts: [Account])] {
        let groups = Dictionary(grouping: activeAccounts, by: \.kind)
        return AccountCategory.Kind.allCases.compactMap { kind in
            let accounts = groups[kind]?.sorted { $0.sortOrder < $1.sortOrder } ?? []
            return accounts.isEmpty ? nil : (kind, accounts)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if activeAccounts.isEmpty {
                ContentUnavailableView {
                    Label("No accounts yet", systemImage: "creditcard")
                } description: {
                    Text("Add your checking, savings, and credit cards to see your real cash position.")
                } actions: {
                    Button {
                        appState.pendingAddSheet = .account()
                    } label: {
                        Text("Add an account").fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.sage)
                }
            } else {
                List {
                    ForEach(groupedAccounts, id: \.kind) { group in
                        Section(group.kind.pluralDisplayName) {
                            ForEach(group.accounts) { account in
                                NavigationLink {
                                    AccountDetailView(account: account)
                                } label: {
                                    AccountRowView(account: account)
                                }
                            }
                            .onDelete { indexSet in
                                delete(at: indexSet, in: group.accounts)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.pendingAddSheet = .account()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet, in accounts: [Account]) {
        for index in offsets {
            modelContext.delete(accounts[index])
        }
        try? modelContext.save()
    }
}
