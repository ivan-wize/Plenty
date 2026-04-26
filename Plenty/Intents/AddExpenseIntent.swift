//
//  AddExpenseIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/AddExpenseIntent.swift
//
//  Write intent. "Add $42 expense for coffee in Plenty."
//
//  Parameters: amount (currency), name (string).
//  Optional: account (resolved by name match).
//
//  Auto-categorizes from the name via ExpenseCategorizer (rules-only;
//  AI in intents would add latency Siri can't tolerate).
//

import AppIntents
import SwiftData
import Foundation

struct AddExpenseIntent: AppIntent {

    static let title: LocalizedStringResource = "Add Expense"

    static let description: IntentDescription = IntentDescription(
        "Log a one-time expense by amount and description.",
        categoryName: "Add"
    )

    @Parameter(title: "Amount", description: "How much you spent.")
    var amount: Double

    @Parameter(title: "What for", description: "What did you spend on?")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "Plenty needs an amount greater than zero.")
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return .result(dialog: "Plenty needs a description for the expense.")
        }

        guard let container = ModelContainerFactory.makeForIntent() else {
            return .result(dialog: "Plenty couldn't open your data right now.")
        }
        let context = container.mainContext

        let amountDecimal = Decimal(amount)
        let category = ExpenseCategorizer.detect(from: trimmedName)
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let sourceAccount = AccountDerivations.defaultSpendingSource(accounts)

        let tx = Transaction.expense(
            name: trimmedName,
            amount: amountDecimal,
            date: .now,
            category: category == .other ? nil : category,
            sourceAccount: sourceAccount
        )
        context.insert(tx)

        do {
            try context.save()
        } catch {
            return .result(dialog: "Plenty couldn't save the expense.")
        }

        return .result(dialog: IntentDialog(stringLiteral: "Added \(amountDecimal.spokenCurrency()) for \(trimmedName)."))
    }
}

private extension Decimal {
    func spokenCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
