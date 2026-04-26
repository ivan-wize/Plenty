//
//  AddBillIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/AddBillIntent.swift
//
//  Write intent. "Add bill rent $1200 due day 1 in Plenty."
//
//  Always creates a recurring monthly bill. Quarterly/annual bills
//  remain UI-only.
//

import AppIntents
import SwiftData
import Foundation

struct AddBillIntent: AppIntent {

    static let title: LocalizedStringResource = "Add Bill"

    static let description: IntentDescription = IntentDescription(
        "Add a recurring monthly bill.",
        categoryName: "Add"
    )

    @Parameter(title: "Amount", description: "How much the bill is.")
    var amount: Double

    @Parameter(title: "Bill name", description: "What is the bill for?")
    var name: String

    @Parameter(title: "Due day", description: "Day of month it's due, 1 through 28.")
    var dueDay: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "Plenty needs an amount greater than zero.")
        }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return .result(dialog: "Plenty needs a name for the bill.")
        }
        guard (1...28).contains(dueDay) else {
            return .result(dialog: "Due day should be 1 through 28.")
        }

        guard let container = ModelContainerFactory.makeForIntent() else {
            return .result(dialog: "Plenty couldn't open your data right now.")
        }
        let context = container.mainContext

        let cal = Calendar.current
        let now = Date.now
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)
        let amountDecimal = Decimal(amount)

        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let source = AccountDerivations.defaultSpendingSource(accounts)

        let bill = Transaction.bill(
            name: trimmedName,
            amount: amountDecimal,
            dueDay: dueDay,
            month: m,
            year: y,
            category: nil,
            sourceAccount: source,
            recurringRule: .monthly(onDay: dueDay, startingFrom: now)
        )
        context.insert(bill)

        do {
            try context.save()
        } catch {
            return .result(dialog: "Plenty couldn't save the bill.")
        }

        return .result(dialog: IntentDialog(stringLiteral: "Added \(trimmedName) for \(amountDecimal.spokenCurrency()) due the \(dueDay.ordinalString) of each month."))
    }
}

private extension Decimal {
    func spokenCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
