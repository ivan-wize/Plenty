//
//  MonthlySummaryIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/MonthlySummaryIntent.swift
//
//  Phase 8 (v2): "Plenty's monthly summary."
//
//  Spoken summary now leads with monthlyBudgetRemaining. Snippet card
//  shows the headline number with sage / terracotta tint to match the
//  in-app hero treatment.
//

import AppIntents
import SwiftData
import SwiftUI
import Foundation

struct MonthlySummaryIntent: AppIntent {

    static let title: LocalizedStringResource = "Monthly Summary"

    static let description: IntentDescription = IntentDescription(
        "Hear the headline numbers for this month: budget left, income, bills, and savings.",
        categoryName: "Budget"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let container = ModelContainerFactory.makeForIntent() else {
            return .result(
                dialog: "Plenty couldn't read your data right now. Try opening the app.",
                view: SnippetUnavailable()
            )
        }

        let context = container.mainContext
        let cal = Calendar.current
        let now = Date.now
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)

        try? IncomeEntryGenerator(context: context).prepareExpectedEntries(month: m, year: y)

        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<SavingsGoal>())) ?? []

        let snapshot = BudgetEngine.calculate(
            accounts: AccountDerivations.activeAccounts(accounts),
            transactions: transactions,
            savingsGoals: goals,
            month: m,
            year: y
        )

        if snapshot.zone == .empty {
            return .result(
                dialog: "No data for this month yet. Open Plenty to add your income or expenses.",
                view: SnippetUnavailable()
            )
        }

        // Build a compact spoken summary in v2 voice.
        var parts: [String] = []

        // Headline: budget remaining.
        if snapshot.monthlyBudgetRemaining < 0 {
            let over = abs(snapshot.monthlyBudgetRemaining).asPlainCurrency()
            parts.append("You're \(over) over your budget.")
        } else if snapshot.monthlyBudgetRemaining == 0 {
            parts.append("You're at zero this month.")
        } else {
            parts.append("\(snapshot.monthlyBudgetRemaining.asPlainCurrency()) left this month.")
        }

        // Income.
        if snapshot.totalIncome > 0 {
            let confirmed = snapshot.confirmedIncome.asPlainCurrency()
            let total = snapshot.totalIncome.asPlainCurrency()
            if snapshot.allIncomeConfirmed {
                parts.append("\(total) in income confirmed.")
            } else {
                parts.append("\(confirmed) of \(total) in income confirmed.")
            }
        }

        // Bills.
        if snapshot.billsTotalCount > 0 {
            let unpaid = snapshot.billsTotalCount - snapshot.billsPaidCount
            if unpaid == 0 {
                parts.append("All bills paid.")
            } else {
                let plural = unpaid == 1 ? "" : "s"
                parts.append("\(unpaid) bill\(plural) still to pay totaling \(snapshot.billsRemaining.asPlainCurrency()).")
            }
        }

        // Savings.
        if snapshot.plannedSavingsThisMonth > 0 {
            let saved = snapshot.actualSavingsThisMonth.asPlainCurrency()
            let planned = snapshot.plannedSavingsThisMonth.asPlainCurrency()
            parts.append("Saved \(saved) of \(planned) planned.")
        }

        let dialog = parts.joined(separator: " ")

        return .result(
            dialog: IntentDialog(stringLiteral: dialog),
            view: MonthlySummarySnippet(snapshot: snapshot)
        )
    }
}

// MARK: - Snippet Views

private struct MonthlySummarySnippet: View {
    let snapshot: PlentySnapshot

    private var headlineColor: Color {
        snapshot.monthlyBudgetRemaining < 0 ? Theme.terracotta : Theme.sage
    }

    private var headlineLabel: String {
        if snapshot.monthlyBudgetRemaining < 0 { return "Over budget" }
        if snapshot.monthlyBudgetRemaining == 0 { return "At zero" }
        return "Left this month"
    }

    private var headlineAmount: String {
        let value = snapshot.monthlyBudgetRemaining
        let abs = value < 0 ? -value : value
        let formatted = abs.asPlainCurrency()
        return value < 0 ? "−\(formatted)" : formatted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headlineLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(headlineAmount)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(headlineColor)
            }

            Divider()

            stat("Income confirmed",
                 value: "\(snapshot.confirmedIncome.asPlainCurrency()) of \(snapshot.totalIncome.asPlainCurrency())")

            stat("Bills",
                 value: "\(snapshot.billsPaidCount) of \(snapshot.billsTotalCount) paid")

            if snapshot.plannedSavingsThisMonth > 0 {
                stat("Savings",
                     value: "\(snapshot.actualSavingsThisMonth.asPlainCurrency()) of \(snapshot.plannedSavingsThisMonth.asPlainCurrency())")
            }
        }
        .padding(16)
    }

    private func stat(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct SnippetUnavailable: View {
    var body: some View {
        Text("Open Plenty to add your data.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(16)
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
