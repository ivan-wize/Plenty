//
//  IncomeListView.swift
//  Plenty
//
//  Target path: Plenty/Features/Income/IncomeListView.swift
//
//  Phase 4 (v2): the main list area on the Income tab. Two grouped
//  sections — Confirmed and Expected — each rendered as IncomeRow.
//
//  Per PDS §4.2:
//    • Confirmed rows — tap-to-edit (skipped for P4; v2.1 adds a
//      simple detail / amount-correction sheet)
//    • Expected rows — tap opens IncomeSourceEditorSheet so the user
//      can tune the recurring template
//    • Both — swipe-leading "Confirm" (Expected only) and
//      swipe-trailing "Delete" / "Edit source"
//
//  This view is the body of the Income tab when there's at least one
//  income entry for the scoped month. The empty state lives on
//  IncomeTab itself.
//

import SwiftUI
import SwiftData

struct IncomeListView: View {

    let confirmed: [Transaction]
    let expected: [Transaction]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var sourceToEdit: IncomeSource?

    var body: some View {
        List {
            if !expected.isEmpty {
                expectedSection
            }

            if !confirmed.isEmpty {
                confirmedSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .sheet(item: $sourceToEdit) { source in
            IncomeSourceEditorSheet(source: source)
        }
    }

    // MARK: - Expected Section

    private var expectedSection: some View {
        Section {
            ForEach(expected) { tx in
                IncomeRow(transaction: tx, onTap: {
                    if let source = tx.incomeSource {
                        sourceToEdit = source
                    }
                })
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        appState.pendingAddSheet = .confirmIncome(tx)
                    } label: {
                        Label("Confirm", systemImage: "checkmark.circle.fill")
                    }
                    .tint(Theme.sage)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(tx)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    if tx.incomeSource != nil {
                        Button {
                            sourceToEdit = tx.incomeSource
                        } label: {
                            Label("Edit source", systemImage: "pencil")
                        }
                        .tint(.indigo)
                    }
                }
            }
        } header: {
            HStack {
                Text("Expected")
                Spacer()
                Text(expectedTotal.asPlainCurrency())
                    .monospacedDigit()
            }
        } footer: {
            Text("Swipe a row to confirm when the money arrives. Tap to edit the recurring template.")
        }
    }

    // MARK: - Confirmed Section

    private var confirmedSection: some View {
        Section {
            ForEach(confirmed) { tx in
                IncomeRow(transaction: tx)
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
                Text("Confirmed")
                Spacer()
                Text(confirmedTotal.asPlainCurrency())
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Totals

    private var confirmedTotal: Decimal {
        confirmed.reduce(Decimal.zero) { $0 + ($1.confirmedAmount ?? $1.amount) }
    }

    private var expectedTotal: Decimal {
        expected.reduce(Decimal.zero) { $0 + ($1.expectedAmount > 0 ? $1.expectedAmount : $1.amount) }
    }

    // MARK: - Actions

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
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
