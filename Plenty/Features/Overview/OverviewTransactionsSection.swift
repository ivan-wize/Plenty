//
//  OverviewTransactionsSection.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/OverviewTransactionsSection.swift
//
//  Phase 3 (v2): the "Recent transactions" section on the Overview tab
//  (PDS §4.1).
//
//  Shows up to three of the most recent expenses for the scoped month,
//  newest first. Empty state offers a calm one-liner with a tap-to-add
//  CTA. "See all" switches to the Expenses tab so the user can drill in
//  with the segmented control and full list.
//
//  Bills are excluded — they have their own dedicated section below
//  (OverviewBillsSection). Transfers are also excluded; they're an
//  internal accounting concept rather than a "transaction" the user
//  thinks about day-to-day.
//

import SwiftUI

struct OverviewTransactionsSection: View {

    let transactions: [Transaction]

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if transactions.isEmpty {
                emptyState
            } else {
                transactionList
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Recent transactions")
                .font(Typography.Body.emphasis)
                .foregroundStyle(.primary)

            Spacer()

            if !transactions.isEmpty {
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
            Image(systemName: "creditcard")
                .font(.body)
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing yet this month.")
                    .font(Typography.Body.regular)
                    .foregroundStyle(.primary)
                Text("Tap + to add a transaction.")
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

    private var transactionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                TransactionRow(transaction: tx)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())

                if index < transactions.count - 1 {
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
}
