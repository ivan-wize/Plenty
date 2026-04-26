//
//  GetPlentyIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/GetPlentyIntent.swift
//
//  Read intent. "How much do I have?" / "Check Plenty."
//
//  Computes the current PlentySnapshot via BudgetEngine and speaks
//  back the spendable amount. Voice matches Plenty's posture: second
//  person, possession-leading, no exclamations.
//
//  Replaces Left's GetLeftIntent. Field references updated for the
//  PlentySnapshot rename ('left' → 'spendable').
//

import AppIntents
import SwiftData
import Foundation

struct GetPlentyIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Spendable"

    static let description: IntentDescription = IntentDescription(
        "See how much you can safely spend right now.",
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

        let activeAccounts = AccountDerivations.activeAccounts(accounts)

        let snapshot = BudgetEngine.calculate(
            accounts: activeAccounts,
            transactions: transactions,
            savingsGoals: goals,
            month: m,
            year: y
        )

        // Empty state: no income or activity to compute against.
        if snapshot.zone == .empty {
            return .result(dialog: "Plenty doesn't have enough data this month yet. Open the app to add your income or expenses.")
        }

        // Build the spoken response.
        var line: String
        if snapshot.spendable < 0 {
            let over = (snapshot.spendable < 0 ? -snapshot.spendable : snapshot.spendable).asPlainCurrency()
            line = "You're past your margin by \(over) this month."
        } else {
            line = "You have \(snapshot.spendable.asPlainCurrency()) spendable this month."
        }

        // Contextual addendum based on zone, kept short for spoken output.
        switch snapshot.zone {
        case .warning:
            line += " Pace deserves a glance."
        case .over:
            // Already handled in the main line.
            break
        case .safe, .empty:
            if snapshot.billsRemaining > 0 {
                let count = snapshot.billsTotalCount - snapshot.billsPaidCount
                let plural = count == 1 ? "" : "s"
                line += " \(count) bill\(plural) still to pay totaling \(snapshot.billsRemaining.asPlainCurrency())."
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
