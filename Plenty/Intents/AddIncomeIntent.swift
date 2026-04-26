//
//  AddIncomeIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/AddIncomeIntent.swift
//
//  Write intent. "Log $200 income from refund in Plenty."
//
//  One-time only. Recurring income (paycheck setup) stays in the app
//  because the cadence configuration is too complex for voice flow.
//

import AppIntents
import SwiftData
import Foundation

struct AddIncomeIntent: AppIntent {

    static let title: LocalizedStringResource = "Log Income"

    static let description: IntentDescription = IntentDescription(
        "Log a one-time income amount.",
        categoryName: "Add"
    )

    @Parameter(title: "Amount", description: "How much you received.")
    var amount: Double

    @Parameter(title: "Source", description: "Where did the money come from?")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "Plenty needs an amount greater than zero.")
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return .result(dialog: "Plenty needs a source for the income.")
        }

        guard let container = ModelContainerFactory.makeForIntent() else {
            return .result(dialog: "Plenty couldn't open your data right now.")
        }
        let context = container.mainContext

        let amountDecimal = Decimal(amount)
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let destination = AccountDerivations.defaultSpendingSource(accounts)

        let tx = Transaction.manualIncome(
            name: trimmedName,
            amount: amountDecimal,
            date: .now,
            category: .paycheck,
            destinationAccount: destination
        )
        context.insert(tx)

        do {
            try context.save()
        } catch {
            return .result(dialog: "Plenty couldn't save the income.")
        }

        return .result(dialog: IntentDialog(stringLiteral: "Logged \(amountDecimal.spokenCurrency()) from \(trimmedName)."))
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
