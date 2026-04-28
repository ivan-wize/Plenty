//
//  TransactionsListView.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/TransactionsListView.swift
//
//  All transactions, sorted newest-first, grouped by month. Optional
//  kind filter via a Menu in the toolbar.
//
//  Phase 5 has no edit-in-place: tapping a transaction is a no-op for
//  now. Swipe-to-delete is supported. A future polish phase can add
//  TransactionDetailView with edit.
//

import SwiftUI
import SwiftData

struct TransactionsListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var filter: KindFilter = .all

    enum KindFilter: String, CaseIterable, Identifiable {
        case all, expenses, transfers, income

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all:        return "All"
            case .expenses:   return "Expenses"
            case .transfers:  return "Transfers"
            case .income:     return "Income"
            }
        }

        func includes(_ tx: Transaction) -> Bool {
            switch self {
            case .all:       return tx.kind != .bill  // Bills are on their own list
            case .expenses:  return tx.kind == .expense
            case .transfers: return tx.kind == .transfer
            case .income:    return tx.kind == .income
            }
        }
    }

    private var filtered: [Transaction] {
        allTransactions.filter(filter.includes)
    }

    private var grouped: [(key: String, value: [Transaction])] {
        let groups = Dictionary(grouping: filtered) { tx -> String in
            Self.groupFormatter.string(from: tx.date)
        }
        return groups.sorted { $0.value.first?.date ?? .distantPast > $1.value.first?.date ?? .distantPast }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label("No transactions", systemImage: "list.bullet")
                } description: {
                    Text("Add an expense, income, or transfer with the Add button.")
                } actions: {
                    Button {
                        appState.pendingAddSheet = .expense
                    } label: {
                        Text("Add expense").fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.sage)
                }
            } else {
                List {
                    ForEach(grouped, id: \.key) { group in
                        Section(group.key) {
                            ForEach(group.value) { tx in
                                TransactionRow(transaction: tx)
                            }
                            .onDelete { indexSet in delete(at: indexSet, in: group.value) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Transactions")
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
