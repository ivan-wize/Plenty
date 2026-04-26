//
//  LogSavingsIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/LogSavingsIntent.swift
//
//  Write intent. "Log $200 toward Vacation in Plenty."
//
//  Parameters: amount, goal name (resolved by case-insensitive match
//  against existing SavingsGoal.name).
//

import AppIntents
import SwiftData
import Foundation

struct LogSavingsIntent: AppIntent {

    static let title: LocalizedStringResource = "Log Savings Contribution"

    static let description: IntentDescription = IntentDescription(
        "Log a contribution to a savings goal by name.",
        categoryName: "Add"
    )

    @Parameter(title: "Amount", description: "How much to contribute.")
    var amount: Double

    @Parameter(title: "Goal name", description: "Which savings goal?")
    var goalName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "Plenty needs an amount greater than zero.")
        }
        let trimmedName = goalName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return .result(dialog: "Plenty needs a goal name.")
        }

        guard let container = ModelContainerFactory.makeForIntent() else {
            return .result(dialog: "Plenty couldn't open your data right now.")
        }
        let context = container.mainContext

        let goals = (try? context.fetch(FetchDescriptor<SavingsGoal>())) ?? []
        let lower = trimmedName.lowercased()
        let matches = goals.filter { $0.name.lowercased().contains(lower) }

        if matches.isEmpty {
            return .result(dialog: "Plenty couldn't find a savings goal matching \(trimmedName).")
        }

        if matches.count > 1 {
            let names = matches.map(\.name).joined(separator: ", ")
            return .result(dialog: IntentDialog(stringLiteral: "Multiple goals match: \(names). Open Plenty to log the contribution to the right one."))
        }

        let goal = matches[0]
        let amountDecimal = Decimal(amount)

        let tx = Transaction.savingsContribution(
            name: goal.name,
            amount: amountDecimal,
            date: .now,
            goal: goal,
            note: nil
        )
        context.insert(tx)

        do {
            try context.save()
        } catch {
            return .result(dialog: "Plenty couldn't save the contribution.")
        }

        let progressLine: String
        let newTotal = goal.contributedAmount
        if newTotal >= goal.targetAmount {
            progressLine = "Goal reached."
        } else {
            let remaining = goal.targetAmount - newTotal
            progressLine = "\(remaining.spokenCurrency()) to go."
        }

        return .result(dialog: IntentDialog(stringLiteral: "Logged \(amountDecimal.spokenCurrency()) toward \(goal.name). \(progressLine)"))
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
