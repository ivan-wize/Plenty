//
//  BillsListView.swift
//  Plenty
//
//  Target path: Plenty/Features/Expenses/Bills/BillsListView.swift
//
//  Phase 5 (v2): month-scoped bills list shown inside the Expenses
//  tab's Bills sub-tab.
//
//  Replaces v1's all-time BillsListView. The list is scoped via
//  MonthScope (rather than always reading the current calendar month)
//  so the user can view, edit, and add bills in any month.
//
//  Affordances:
//    • Unpaid section, sorted by dueDay ascending, with running total
//    • Paid section below
//    • BillRow's tap-to-edit and tap-to-mark-paid both work
//    • Empty-state CTA: Add a bill / Copy from previous month
//    • Bottom-of-list "Copy from previous month" button when the
//      previous month has bills, even if the current month has some
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "bills-list")

struct BillsListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(MonthScope.self) private var monthScope

    @Query private var allTransactions: [Transaction]

    @State private var billToEdit: Transaction?
    @State private var showingCopySheet = false

    // MARK: - Derived

    private var monthBills: [Transaction] {
        TransactionProjections.bills(
            allTransactions,
            month: monthScope.month,
            year: monthScope.year
        )
    }

    private var unpaidBills: [Transaction] {
        monthBills
            .filter { !$0.isPaid }
            .sorted { $0.dueDay < $1.dueDay }
    }

    private var paidBills: [Transaction] {
        monthBills
            .filter { $0.isPaid }
            .sorted { $0.dueDay < $1.dueDay }
    }

    private var unpaidTotal: Decimal {
        unpaidBills.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var paidTotal: Decimal {
        paidBills.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var previousMonthScope: (month: Int, year: Int) {
        var m = monthScope.month - 1
        var y = monthScope.year
        if m < 1 { m = 12; y -= 1 }
        return (m, y)
    }

    private var previousMonthBills: [Transaction] {
        TransactionProjections.bills(
            allTransactions,
            month: previousMonthScope.month,
            year: previousMonthScope.year
        )
        .sorted { $0.dueDay < $1.dueDay }
    }

    private var previousMonthLabel: String {
        var comps = DateComponents()
        comps.year = previousMonthScope.year
        comps.month = previousMonthScope.month
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return "previous month" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    // MARK: - Body

    var body: some View {
        Group {
            if monthBills.isEmpty {
                emptyState
            } else {
                populated
            }
        }
        .sheet(item: $billToEdit) { bill in
            BillEditorSheet(bill: bill)
        }
        .sheet(isPresented: $showingCopySheet) {
            copySheet
        }
    }

    // MARK: - Populated

    private var populated: some View {
        VStack(spacing: 0) {
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
                            Text(unpaidTotal.asPlainCurrency())
                                .monospacedDigit()
                        }
                    }
                }

                if !paidBills.isEmpty {
                    Section {
                        ForEach(paidBills) { bill in
                            BillRow(
                                bill: bill,
                                onTogglePaid: { togglePaid(bill) },
                                onTap: { billToEdit = bill }
                            )
                        }
                        .onDelete { indexSet in delete(at: indexSet, in: paidBills) }
                    } header: {
                        HStack {
                            Text("Paid")
                            Spacer()
                            Text(paidTotal.asPlainCurrency())
                                .monospacedDigit()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
        .safeAreaInset(edge: .bottom) {
            if !previousMonthBills.isEmpty {
                copyFromPreviousButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                ContentUnavailableView {
                    Label("No bills yet this month", systemImage: "doc.text")
                        .foregroundStyle(Theme.sage)
                } description: {
                    Text("Add a bill or bring it forward from \(previousMonthLabel).")
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                VStack(spacing: 10) {
                    Button {
                        appState.pendingAddSheet = .bill()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Add a bill")
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

                    if !previousMonthBills.isEmpty {
                        Button {
                            showingCopySheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Copy from \(previousMonthLabel)")
                                    .font(Typography.Body.emphasis)
                                    .foregroundStyle(Theme.sage)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .stroke(Theme.sage, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Copy Button

    private var copyFromPreviousButton: some View {
        Button {
            showingCopySheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.on.square")
                    .font(.body)
                Text("Copy from \(previousMonthLabel)")
                    .font(Typography.Body.regular)
                Spacer()
            }
            .foregroundStyle(Theme.sage)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Copy Sheet

    @ViewBuilder
    private var copySheet: some View {
        CopyFromPreviousMonthSheet<Transaction>(
            title: "Copy bills",
            subtitle: "Bringing forward bills from \(previousMonthLabel).",
            sourceItems: previousMonthBills,
            summarize: { bill in
                CopyItemSummary(
                    name: bill.name,
                    defaultAmount: bill.amount,
                    secondary: "Due \(bill.dueDay.ordinalString)"
                )
            },
            onCopy: { selections in
                applyCopiedBills(selections)
            }
        )
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

    private func applyCopiedBills(_ selections: [CopySelection<Transaction>]) {
        let now = Date.now

        for selection in selections {
            let original = selection.source
            let new = Transaction.bill(
                name: original.name,
                amount: selection.amount,
                dueDay: original.dueDay,
                month: monthScope.month,
                year: monthScope.year,
                category: original.category,
                sourceAccount: original.sourceAccount,
                recurringRule: .monthly(onDay: original.dueDay, startingFrom: now)
            )
            new.copiedFromID = original.id
            modelContext.insert(new)
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Copy bills save failed: \(error.localizedDescription)")
        }
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
