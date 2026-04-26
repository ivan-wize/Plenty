//
//  WatchBillsView.swift
//  Plenty
//
//  Target path: PlentyWatch/WatchBillsView.swift
//
//  Bills checklist for the Watch. Vertical scroll of unpaid bills.
//  Tap to mark paid. Success haptic on toggle.
//
//  Watch is for quick actions: no edit, no delete, no add. Those
//  remain on iPhone.
//

import SwiftUI
import SwiftData

struct WatchBillsView: View {

    @Environment(\.modelContext) private var modelContext

    let bills: [Transaction]

    @State private var paidIDs: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(bills) { bill in
                    row(for: bill)
                }

                if bills.isEmpty {
                    emptyState
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .navigationTitle("Bills")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Row

    private func row(for bill: Transaction) -> some View {
        Button {
            markPaid(bill)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: paidIDs.contains(bill.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(paidIDs.contains(bill.id) ? Theme.sage : .secondary)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 1) {
                    Text(bill.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(paidIDs.contains(bill.id) ? .secondary : .primary)
                        .strikethrough(paidIDs.contains(bill.id))
                        .lineLimit(1)

                    Text("Due \(bill.dueDay.ordinalString)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(bill.amount.asCompactCurrency())
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(paidIDs.contains(bill.id) ? .secondary : .primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(paidIDs.contains(bill.id)
                          ? Theme.sage.opacity(0.1)
                          : Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: paidIDs.contains(bill.id))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.sage)
            Text("All bills paid")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Mark Paid

    private func markPaid(_ bill: Transaction) {
        guard !paidIDs.contains(bill.id) else { return }

        // Animate the toggle locally; commit to data layer.
        withAnimation(.snappy) {
            paidIDs.insert(bill.id)
        }
        bill.markPaid()
        try? modelContext.save()
    }
}

private extension Decimal {
    func asCompactCurrency() -> String {
        let value = NSDecimalNumber(decimal: self).doubleValue
        let absValue = abs(value)
        if absValue >= 1_000 {
            return String(format: "$%.1fk", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }
}
