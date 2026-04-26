//
//  LogContributionSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/LogContributionSheet.swift
//
//  Quick sheet to log a contribution to an existing goal. Pre-shows
//  goal name and progress; user enters amount and an optional note.
//  Creates a Transaction tagged to the goal.
//

import SwiftUI
import SwiftData

struct LogContributionSheet: View {

    let goal: SavingsGoal

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Decimal = 0
    @State private var note: String = ""
    @FocusState private var amountFocused: Bool

    private var canSave: Bool { amount > 0 }

    private var newTotal: Decimal {
        goal.contributedAmount + amount
    }

    private var newProgress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        let new = (newTotal / goal.targetAmount as NSDecimalNumber).doubleValue
        return min(1, max(0, new))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                amountSection
                progressPreview
                noteSection
            }
            .navigationTitle("Log Contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear { amountFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            HStack {
                Image(systemName: "leaf")
                    .foregroundStyle(Theme.sage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(Typography.Body.regular)
                    Text("\(goal.contributedAmount.asPlainCurrency()) of \(goal.targetAmount.asPlainCurrency())")
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var amountSection: some View {
        Section {
            HStack {
                Text("$")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                CurrencyField(value: $amount, prompt: "0", accent: Theme.sage)
            }
        } header: {
            Text("Contribution")
        }
    }

    @ViewBuilder
    private var progressPreview: some View {
        if amount > 0 {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("New total")
                        Spacer()
                        Text(newTotal.asPlainCurrency())
                            .monospacedDigit()
                            .foregroundStyle(Theme.sage)
                    }
                    .font(Typography.Body.regular)

                    ProgressView(value: newProgress)
                        .tint(Theme.sage)

                    if newTotal >= goal.targetAmount {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.sage)
                            Text("Goal reached")
                                .font(Typography.Support.footnote)
                                .foregroundStyle(Theme.sage)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var noteSection: some View {
        Section("Note (optional)") {
            TextField("e.g. tax refund deposit", text: $note)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Log") { save() }
                .fontWeight(.semibold)
                .disabled(!canSave)
        }
    }

    // MARK: - Actions

    private func save() {
        let tx = Transaction.savingsContribution(
            name: goal.name,
            amount: amount,
            date: .now,
            goal: goal,
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
        )
        modelContext.insert(tx)
        try? modelContext.save()
        dismiss()
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
