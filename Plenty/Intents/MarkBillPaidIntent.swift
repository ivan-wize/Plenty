//
//  MarkBillPaidIntent.swift
//  Plenty
//
//  Target path: Plenty/Intents/MarkBillPaidIntent.swift
//
//  Write intent. "Mark rent paid in Plenty."
//
//  Parameter: bill name. Matches against this month's unpaid bills
//  by case-insensitive prefix. If multiple match, asks for clarification.
//

import AppIntents
import SwiftData
import Foundation

struct MarkBillPaidIntent: AppIntent {

    static let title: LocalizedStringResource = "Mark Bill Paid"

    static let description: IntentDescription = IntentDescription(
        "Mark a bill as paid by name.",
        categoryName: "Add"
    )

    @Parameter(title: "Bill name", description: "Name of the bill to mark paid.")
    var billName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedName = billName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return .result(dialog: "Plenty needs a bill name.")
        }

        guard let container = ModelContainerFactory.makeForIntent() else {
            return .result(dialog: "Plenty couldn't open your data right now.")
        }
        let context = container.mainContext

        let cal = Calendar.current
        let now = Date.now
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)

        let allTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let unpaid = TransactionProjections.bills(allTransactions, month: m, year: y).filter { !$0.isPaid }

        let lower = trimmedName.lowercased()
        let matches = unpaid.filter { $0.name.lowercased().contains(lower) }

        if matches.isEmpty {
            return .result(dialog: "Plenty couldn't find an unpaid bill matching \(trimmedName) this month.")
        }

        if matches.count > 1 {
            let names = matches.map(\.name).joined(separator: ", ")
            return .result(dialog: IntentDialog(stringLiteral: "Multiple bills match: \(names). Open Plenty to mark the right one paid."))
        }

        let bill = matches[0]
        bill.markPaid()

        do {
            try context.save()
        } catch {
            return .result(dialog: "Plenty couldn't save the change.")
        }

        return .result(dialog: IntentDialog(stringLiteral: "Marked \(bill.name) paid."))
    }
}
