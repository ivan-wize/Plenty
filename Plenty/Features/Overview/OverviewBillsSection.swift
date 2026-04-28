//
//  OverviewBillsSection.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/OverviewBillsSection.swift
//
//  Phase 3 (v2): the "Upcoming bills" section on the Overview tab
//  (PDS §4.1).
//
//  Shows up to three unpaid bills for the scoped month, ordered by due
//  day ascending. Each row uses the existing BillRow component, which
//  already provides the tap-to-mark-paid leading circle. Tapping the
//  row body opens the bill editor.
//
//  Empty state appears when there are no unpaid bills (either none
//  exist, or all are paid). "See all" switches to the Expenses tab.
//

import SwiftUI
import SwiftData

struct OverviewBillsSection: View {

    let bills: [Transaction]

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var billToEdit: Transaction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if bills.isEmpty {
                emptyState
            } else {
                billList
            }
        }
        .sheet(item: $billToEdit) { bill in
            BillEditorSheet(bill: bill)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Upcoming bills")
                .font(Typography.Body.emphasis)
                .foregroundStyle(.primary)

            Spacer()

            if !bills.isEmpty {
                Button {
                    appState.selectedTab = .expenses
                } label: {
                    Text("See all")
                        .font(Typography.Support.footnote)
                        .foregroundStyle(Theme.sage)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Switches to the Expenses tab.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.body)
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

            VStack(alignment: .leading, spacing: 2) {
                Text("No upcoming bills.")
                    .font(Typography.Body.regular)
                    .foregroundStyle(.primary)
                Text("Tap + to add a bill.")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    // MARK: - List

    private var billList: some View {
        VStack(spacing: 0) {
            ForEach(Array(bills.enumerated()), id: \.element.id) { index, bill in
                BillRow(
                    bill: bill,
                    onTogglePaid: { togglePaid(bill) },
                    onTap: { billToEdit = bill }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                if index < bills.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
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
}
