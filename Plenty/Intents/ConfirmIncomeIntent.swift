//
//  ConfirmIncomeIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/ConfirmIncomeIntent.swift
//
//  Write intent. "Confirm my paycheck in Plenty."
//
//  Finds the next expected income entry due today or earlier and
//  confirms it with the optional override amount (or the expected
//  amount if not provided).
//

import AppIntents
import SwiftData
import Foundation

struct ConfirmIncomeIntent: AppIntent {

    static let title: LocalizedStringResource = "Confirm Income"

    static let description: IntentDescription = IntentDescription(
        "Confirm the most recent expected paycheck arrived.",
        categoryName: "Add"
    )

    @Parameter(title: "Actual amount", description: "Override the expected amount, optional.")
    var actualAmount: Double?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = ModelContainerFactory.makeForIntent() else {
            return .result(dialog: "Plenty couldn't open your data right now.")
        }
        let context = container.mainContext

        let allTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let cal = Calendar.current
        let now = Date.now

        // Expected income due today or earlier this month.
        let cutoff = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
        let expected = allTransactions
            .filter { $0.kind == .income && $0.incomeStatus == .expected && $0.date <= cutoff }
            .sorted { $0.date < $1.date }

        if expected.isEmpty {
            return .result(dialog: "No expected paychecks waiting to confirm.")
        }

        if expected.count > 1 {
            let names = expected.prefix(3).map(\.name).joined(separator: ", ")
            return .result(dialog: IntentDialog(stringLiteral: "Multiple paychecks waiting: \(names). Open Plenty to confirm the right one."))
        }

        let income = expected[0]
        let finalAmount = actualAmount.map { Decimal($0) } ?? income.expectedAmount
        income.confirmIncome(actualAmount: finalAmount)

        do {
            try context.save()
        } catch {
            return .result(dialog: "Plenty couldn't save the change.")
        }

        let differs = finalAmount != income.expectedAmount
        let line: String
        if differs {
            line = "Confirmed \(income.name) at \(finalAmount.spokenCurrency())."
        } else {
            line = "Confirmed \(income.name) for \(finalAmount.spokenCurrency())."
        }
        return .result(dialog: IntentDialog(stringLiteral: line))
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
