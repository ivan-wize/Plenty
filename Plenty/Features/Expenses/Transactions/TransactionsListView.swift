//
//  TransactionsListView.swift
//  Plenty
//
//  Target path: Plenty/Features/Expenses/Transactions/TransactionsListView.swift
//
//  Phase 5 (v2): month-scoped transactions list shown inside the
//  Expenses tab's Transactions sub-tab.
//
//  Replaces v1's all-time TransactionsListView. The all-time history
//  still exists per-account via AccountTransactionsView (in
//  Plan → Accounts), which is unchanged.
//
//  Filters in this view:
//    • Month: from MonthScope
//    • Kind:  expense + transfer (income lives in the Income tab,
//             bills in the Bills sub-tab)
//
//  Affordances:
//    • Total of expenses + transfers shown at the top of the section
//    • Tap a row → AddExpenseSheet pre-filled for editing
//    • Swipe-trailing → Delete
//

import SwiftUI
import SwiftData

struct TransactionsListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(MonthScope.self) private var monthScope

    @Query private var allTransactions: [Transaction]

    @State private var transactionToEdit: Transaction?

    // MARK: - Derived

    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions
            .filter { tx in
                guard tx.kind == .expense || tx.kind == .transfer else { return false }
                let m = cal.component(.month, from: tx.date)
                let y = cal.component(.year, from: tx.date)
                return m == monthScope.month && y == monthScope.year
            }
            .sorted { $0.date > $1.date }
    }

    private var expensesTotal: Decimal {
        monthTransactions
            .filter { $0.kind == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if monthTransactions.isEmpty {
                emptyState
            } else {
                populated
            }
        }
        .sheet(item: $transactionToEdit) { tx in
            AddExpenseSheet(existing: tx)
        }
    }

    // MARK: - Populated

    private var populated: some View {
        List {
            Section {
                ForEach(monthTransactions) { tx in
                    TransactionRow(transaction: tx)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Only expenses are editable; transfers are
                            // edited via the Accounts pane in P6.
                            if tx.kind == .expense {
                                transactionToEdit = tx
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(tx)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Spent this month")
                    Spacer()
                    Text(expensesTotal.asPlainCurrency())
                        .monospacedDigit()
                }
            } footer: {
                Text("Tap a transaction to edit. Swipe to delete.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No transactions yet", systemImage: "creditcard")
                .foregroundStyle(Theme.sage)
        } description: {
            Text("Tap + below to add an expense, or scan a receipt.")
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 60)
    }

    // MARK: - Actions

    private func delete(_ tx: Transaction) {
        modelContext.delete(tx)
        try? modelContext.save()
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
