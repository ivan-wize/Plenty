//
//  SpendingBreakdownIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/SpendingBreakdownIntent.swift
//
//  Read intent. "Show my spending breakdown."
//
//  Returns the top 5 spending categories this month. Spoken output
//  names the top three. Snippet view renders all five with
//  proportional bars.
//

import AppIntents
import SwiftData
import SwiftUI
import Foundation

struct SpendingBreakdownIntent: AppIntent {

    static let title: LocalizedStringResource = "Spending Breakdown"

    static let description: IntentDescription = IntentDescription(
        "See where your money went this month, by category.",
        categoryName: "Budget"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let container = ModelContainerFactory.makeForIntent() else {
            return .result(
                dialog: "Plenty couldn't read your data right now.",
                view: BreakdownUnavailable()
            )
        }

        let context = container.mainContext
        let cal = Calendar.current
        let now = Date.now
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)

        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let monthBills = TransactionProjections.bills(transactions, month: m, year: y)
        let monthExpenses = TransactionProjections.expenses(transactions, month: m, year: y)
        let breakdown = TransactionProjections.categoryBreakdown(bills: monthBills, expenses: monthExpenses)

        if breakdown.isEmpty {
            return .result(
                dialog: "No spending recorded this month yet.",
                view: BreakdownUnavailable()
            )
        }

        let top5 = Array(breakdown.prefix(5))
        let total = breakdown.reduce(Decimal.zero) { $0 + $1.amount }

        // Spoken: top three.
        let topThree = top5.prefix(3)
        let spoken = topThree
            .map { "\($0.displayName) \($0.amount.asPlainCurrency())" }
            .joined(separator: ", ")
        let dialog = "This month: \(spoken). Total \(total.asPlainCurrency())."

        return .result(
            dialog: IntentDialog(stringLiteral: dialog),
            view: BreakdownSnippet(items: top5, total: total)
        )
    }
}

// MARK: - Snippet Views

private struct BreakdownSnippet: View {
    let items: [CategoryBreakdown]
    let total: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top Categories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(total.asPlainCurrency())
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            ForEach(items) { item in
                row(for: item)
            }
        }
        .padding(16)
    }

    private func row(for item: CategoryBreakdown) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.iconName)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(item.displayName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(item.amount.asPlainCurrency())
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct BreakdownUnavailable: View {
    var body: some View {
        Text("Add some expenses to see your breakdown.")
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
