//
//  WatchConfirmIncomeView.swift
//  Plenty
//
//  Target path: PlentyWatch/WatchConfirmIncomeView.swift
//
//  Compact confirm-or-skip view for an expected paycheck. Two
//  primary actions:
//    Confirm — accepts at the expected amount
//    Skip    — marks paycheck didn't arrive
//
//  Long-press on Confirm opens an amount picker (Digital Crown
//  scrub) for cases where the actual amount differs from expected.
//

import SwiftUI
import SwiftData

struct WatchConfirmIncomeView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction

    @State private var actualAmount: Double
    @State private var isAdjusting = false

    init(transaction: Transaction) {
        self.transaction = transaction
        self._actualAmount = State(initialValue: NSDecimalNumber(decimal: transaction.expectedAmount).doubleValue)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                amountDisplay

                if isAdjusting {
                    adjustmentControl
                }

                actionButtons
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .navigationTitle(transaction.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        VStack(spacing: 4) {
            Text(isAdjusting ? "Actual" : "Expected")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(formattedAmount)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.sage)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Adjustment

    private var adjustmentControl: some View {
        VStack(spacing: 6) {
            Text("Digital Crown to adjust")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Slider(value: $actualAmount, in: 0...max(actualAmount * 2, 5000), step: 1)
                .tint(Theme.sage)
                .focusable()
                .digitalCrownRotation($actualAmount, from: 0, through: max(actualAmount * 2, 5000), by: 1, sensitivity: .medium)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 6) {
            Button {
                confirm()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirm")
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .background(Theme.sage)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in
                        withAnimation(.snappy) { isAdjusting = true }
                    }
            )

            if !isAdjusting {
                Button(role: .destructive) {
                    skip()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Skip")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Computed

    private var formattedAmount: String {
        let formatted: String
        if actualAmount >= 1_000 {
            formatted = String(format: "$%.0f", actualAmount)
        } else {
            formatted = String(format: "$%.0f", actualAmount)
        }
        return formatted
    }

    // MARK: - Actions

    private func confirm() {
        transaction.confirmIncome(actualAmount: Decimal(actualAmount))
        try? modelContext.save()
        dismiss()
    }

    private func skip() {
        transaction.skipIncome()
        try? modelContext.save()
        dismiss()
    }
}
