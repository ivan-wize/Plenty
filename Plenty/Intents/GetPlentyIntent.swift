//
//  GetPlentyIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/GetPlentyIntent.swift
//
//  Phase 8 (v2): "How much do I have?" / "Check Plenty."
//
//  Speaks back the v2 hero — `monthlyBudgetRemaining`. Voice matches
//  Plenty's posture: second person, possession-leading, no
//  exclamations.
//
//  Title and description updated to "Check Budget" since "Spendable"
//  is no longer the user-facing concept.
//

import AppIntents
import SwiftData
import Foundation

struct GetPlentyIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Budget"

    static let description: IntentDescription = IntentDescription(
        "See how much budget you have left this month.",
        categoryName: "Budget"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = ModelContainerFactory.makeForIntent() else {
            return .result(dialog: "Plenty couldn't read your data right now. Try opening the app.")
        }

        let context = container.mainContext
        let cal = Calendar.current
        let now = Date.now
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)

        // Generator runs idempotently. Without this, an early-month
        // intent call could miss expected income that the main app
        // hasn't opened yet to materialize.
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

        // Empty state: no income or activity to compute against.
        if snapshot.zone == .empty {
            return .result(dialog: "Plenty doesn't have enough data this month yet. Open the app to add your income or expenses.")
        }

        // Build the spoken response using v2 vocabulary.
        var line: String
        if snapshot.monthlyBudgetRemaining < 0 {
            let over = abs(snapshot.monthlyBudgetRemaining).asPlainCurrency()
            line = "You're \(over) over your budget this month."
        } else if snapshot.monthlyBudgetRemaining == 0 {
            line = "You're at zero this month — every dollar is spoken for."
        } else {
            line = "You have \(snapshot.monthlyBudgetRemaining.asPlainCurrency()) left this month."
        }

        // Optional addendum.
        if snapshot.monthlyBudgetRemaining >= 0 {
            // Surface unpaid bills count when meaningful.
            if snapshot.billsRemaining > 0 {
                let count = snapshot.billsTotalCount - snapshot.billsPaidCount
                let plural = count == 1 ? "" : "s"
                line += " \(count) bill\(plural) still to pay totaling \(snapshot.billsRemaining.asPlainCurrency())."
            } else if snapshot.expectedIncomeRemaining > 0 {
                let amount = snapshot.expectedIncomeRemaining.asPlainCurrency()
                line += " \(amount) more in income expected this month."
            }
        }

        return .result(dialog: IntentDialog(stringLiteral: line))
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
