//
//  ConfirmIncomeSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/ConfirmIncomeSheet.swift
//
//  Confirms that an expected paycheck has arrived. Pre-fills with the
//  expected amount; user can edit the actual amount if it differs. Two
//  primary actions:
//
//    Confirm — flips status to .confirmed, sets confirmedAmount and
//              amount to whatever the user entered.
//    Skip    — flips status to .skipped (paycheck didn't arrive).
//

import SwiftUI
import SwiftData

struct ConfirmIncomeSheet: View {

    let transaction: Transaction

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var actualAmount: Decimal
    @State private var showSkipConfirmation = false

    init(transaction: Transaction) {
        self.transaction = transaction
        _actualAmount = State(initialValue: transaction.expectedAmount)
    }

    private var canConfirm: Bool { actualAmount > 0 }
    private var differsFromExpected: Bool { actualAmount != transaction.expectedAmount }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                amountSection
                if differsFromExpected {
                    differenceNote
                }
                actionsSection
            }
            .navigationTitle("Confirm Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Skip this paycheck?",
                isPresented: $showSkipConfirmation,
                titleVisibility: .visible
            ) {
                Button("Skip", role: .destructive) { skip() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Use this when the paycheck didn't arrive. You can revert later.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(Theme.sage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.name)
                        .font(Typography.Body.regular)
                    Text(formattedDate)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Expected")
                    .font(Typography.Support.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var amountSection: some View {
        Section {
            HStack {
                Text("$")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                CurrencyField(value: $actualAmount, prompt: "0", accent: Theme.sage)
            }
        } header: {
            Text("Actual amount")
        } footer: {
            Text("Pre-filled with the expected amount. Edit if your paycheck was different.")
                .font(Typography.Support.caption)
        }
    }

    private var differenceNote: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Theme.amber)
                Text(differenceMessage)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                confirm()
            } label: {
                HStack {
                    Spacer()
                    Text("Confirm")
                        .font(Typography.Body.emphasis)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Theme.sage)
            .foregroundStyle(.white)
            .disabled(!canConfirm)

            Button(role: .destructive) {
                showSkipConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Skip this paycheck")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func confirm() {
        transaction.confirmIncome(actualAmount: actualAmount)
        try? modelContext.save()
        dismiss()
    }

    private func skip() {
        transaction.skipIncome()
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helpers

    private var formattedDate: String {
        Self.dateFormatter.string(from: transaction.date)
    }

    private var differenceMessage: String {
        let diff = actualAmount - transaction.expectedAmount
        let absDiff = (diff < 0 ? -diff : diff).asPlainCurrency()
        return diff > 0
            ? "That's \(absDiff) more than expected."
            : "That's \(absDiff) less than expected."
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()
}

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
