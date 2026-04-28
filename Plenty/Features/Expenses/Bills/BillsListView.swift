//
//  BillsListView.swift
//  Plenty
//
//  Target path: Plenty/Features/Accounts/BillsListView.swift
//
//  Lists all bills for the current month, grouped into Unpaid and Paid
//  sections. Row taps open the bill editor; circle taps mark
//  paid/unpaid via BillRow's onTogglePaid. Toolbar Add button adds.
//

import SwiftUI
import SwiftData

struct BillsListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Transaction.dueDay) private var allTransactions: [Transaction]

    @State private var billToEdit: Transaction?

    private var month: Int { Calendar.current.component(.month, from: .now) }
    private var year:  Int { Calendar.current.component(.year,  from: .now) }

    private var monthBills: [Transaction] {
        TransactionProjections.bills(allTransactions, month: month, year: year)
            .sorted { $0.dueDay < $1.dueDay }
    }

    private var unpaidBills: [Transaction] {
        monthBills.filter { !$0.isPaid }
    }

    private var paidBills: [Transaction] {
        monthBills.filter(\.isPaid)
    }

    private var totalRemaining: Decimal {
        TransactionProjections.billsRemaining(monthBills)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if monthBills.isEmpty {
                ContentUnavailableView {
                    Label("No bills this month", systemImage: "doc.text")
                } description: {
                    Text("Add your recurring obligations to see them here.")
                } actions: {
                    Button {
                        appState.pendingAddSheet = .bill()
                    } label: {
                        Text("Add a bill").fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.sage)
                }
            } else {
                List {
                    if !unpaidBills.isEmpty {
                        Section {
                            ForEach(unpaidBills) { bill in
                                BillRow(
                                    bill: bill,
                                    onTogglePaid: { togglePaid(bill) },
                                    onTap: { billToEdit = bill }
                                )
                            }
                            .onDelete { indexSet in delete(at: indexSet, in: unpaidBills) }
                        } header: {
                            HStack {
                                Text("Unpaid")
                                Spacer()
                                Text(totalRemaining.asPlainCurrency())
                                    .monospacedDigit()
                            }
                        }
                    }

                    if !paidBills.isEmpty {
                        Section("Paid") {
                            ForEach(paidBills) { bill in
                                BillRow(
                                    bill: bill,
                                    onTogglePaid: { togglePaid(bill) },
                                    onTap: { billToEdit = bill }
                                )
                            }
                            .onDelete { indexSet in delete(at: indexSet, in: paidBills) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Bills")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.pendingAddSheet = .bill()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $billToEdit) { bill in
            BillEditorSheet(bill: bill)
        }
    }

    // MARK: - Actions

    private func togglePaid(_ bill: Transaction) {
        if bill.isPaid {
            bill.markUnpaid()
        } else {
            bill.markPaid()
        }
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet, in bills: [Transaction]) {
        for index in offsets {
            modelContext.delete(bills[index])
        }
        try? modelContext.save()
    }
}

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
