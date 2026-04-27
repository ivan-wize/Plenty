//
//  AccountTransactionsView.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/AccountTransactionsView.swift
//
//  Full transaction history for a single account. Pushed from
//  AccountDetailView when the account has more than 20 transactions
//  ("See all 156 transactions →").
//
//  Layout matches TransactionsListView (the global list): grouped by
//  month, descending, with a kind filter in the toolbar. The
//  filter set is the same minus "all bills" since bills are
//  account-scoped here too.
//
//  Account scoping: matches transactions where this account is the
//  source OR destination. That captures expenses paid from the account,
//  income deposited to it, and transfers either direction.
//

import SwiftUI
import SwiftData

struct AccountTransactionsView: View {

    let account: Account

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var filter: KindFilter = .all

    enum KindFilter: String, CaseIterable, Identifiable {
        case all, expenses, bills, income, transfers

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all:       return "All"
            case .expenses:  return "Expenses"
            case .bills:     return "Bills"
            case .income:    return "Income"
            case .transfers: return "Transfers"
            }
        }

        func includes(_ tx: Transaction) -> Bool {
            switch self {
            case .all:       return true
            case .expenses:  return tx.kind == .expense
            case .bills:     return tx.kind == .bill
            case .income:    return tx.kind == .income
            case .transfers: return tx.kind == .transfer
            }
        }
    }

    private var accountTransactions: [Transaction] {
        allTransactions.filter { tx in
            tx.sourceAccount?.id == account.id || tx.destinationAccount?.id == account.id
        }
    }

    private var filtered: [Transaction] {
        accountTransactions.filter(filter.includes)
    }

    private var grouped: [(key: String, value: [Transaction])] {
        let groups = Dictionary(grouping: filtered) { tx -> String in
            Self.groupFormatter.string(from: tx.date)
        }
        return groups.sorted {
            $0.value.first?.date ?? .distantPast > $1.value.first?.date ?? .distantPast
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    summarySection

                    ForEach(grouped, id: \.key) { group in
                        Section(group.key) {
                            ForEach(group.value) { tx in
                                TransactionRow(transaction: tx, showsAccount: false)
                            }
                            .onDelete { indexSet in
                                delete(at: indexSet, in: group.value)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $filter) {
                        ForEach(KindFilter.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(filter == .all ? "Total transactions" : filter.displayName.lowercased())
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(filtered.count)")
                        .font(Typography.Body.emphasis.monospacedDigit())
                }
                Spacer()
                if filter == .all && !filtered.isEmpty {
                    if let earliest = filtered.last?.date {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("First")
                                .font(Typography.Support.footnote)
                                .foregroundStyle(.secondary)
                            Text(earliest.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(Typography.Body.emphasis.monospacedDigit())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No transactions", systemImage: "list.bullet")
        } description: {
            switch filter {
            case .all:
                Text("This account has no transactions yet.")
            default:
                Text("No \(filter.displayName.lowercased()) for this account.")
            }
        }
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet, in transactions: [Transaction]) {
        for index in offsets {
            modelContext.delete(transactions[index])
        }
        try? modelContext.save()
    }

    // MARK: - Formatter

    private static let groupFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}
