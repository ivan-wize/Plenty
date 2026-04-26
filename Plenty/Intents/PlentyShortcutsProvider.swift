//
//  PlentyShortcutsProvider.swift
//  Plenty
//
//  Target path: Plenty/Intents/PlentyShortcutsProvider.swift
//
//  Phase 4: 3 read intents.
//  Phase 7: + 6 write intents.
//
//  All nine intents now registered:
//    Read:
//      • GetPlentyIntent          — "How much do I have?"
//      • MonthlySummaryIntent     — "Plenty monthly summary"
//      • SpendingBreakdownIntent  — "Show my spending breakdown"
//    Write:
//      • AddExpenseIntent         — "Add expense in Plenty"
//      • AddIncomeIntent          — "Log income in Plenty"
//      • AddBillIntent            — "Add bill in Plenty"
//      • MarkBillPaidIntent       — "Mark bill paid in Plenty"
//      • LogSavingsIntent         — "Log savings in Plenty"
//      • ConfirmIncomeIntent      — "Confirm my paycheck"
//

import AppIntents

struct PlentyShortcutsProvider: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {

        // Read intents (Phase 4)

        AppShortcut(
            intent: GetPlentyIntent(),
            phrases: [
                "How much do I have in \(.applicationName)",
                "What's my spendable in \(.applicationName)",
                "Check \(.applicationName)",
                "What's left in \(.applicationName)",
            ],
            shortTitle: "Check Spendable",
            systemImageName: "dollarsign.circle"
        )

        AppShortcut(
            intent: MonthlySummaryIntent(),
            phrases: [
                "Show my \(.applicationName) summary",
                "\(.applicationName) monthly summary",
            ],
            shortTitle: "Monthly Summary",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: SpendingBreakdownIntent(),
            phrases: [
                "Show my spending in \(.applicationName)",
                "Spending breakdown in \(.applicationName)",
            ],
            shortTitle: "Spending Breakdown",
            systemImageName: "chart.pie"
        )

        // Write intents (Phase 7)

        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Log expense in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "minus.circle"
        )

        AppShortcut(
            intent: AddIncomeIntent(),
            phrases: [
                "Log income in \(.applicationName)",
                "Add income in \(.applicationName)",
            ],
            shortTitle: "Log Income",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: AddBillIntent(),
            phrases: [
                "Add bill in \(.applicationName)",
            ],
            shortTitle: "Add Bill",
            systemImageName: "doc.text"
        )

        AppShortcut(
            intent: MarkBillPaidIntent(),
            phrases: [
                "Mark bill paid in \(.applicationName)",
                "Pay bill in \(.applicationName)",
            ],
            shortTitle: "Mark Bill Paid",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: LogSavingsIntent(),
            phrases: [
                "Log savings in \(.applicationName)",
                "Save toward a goal in \(.applicationName)",
            ],
            shortTitle: "Log Savings",
            systemImageName: "leaf"
        )

        AppShortcut(
            intent: ConfirmIncomeIntent(),
            phrases: [
                "Confirm my paycheck in \(.applicationName)",
                "Confirm income in \(.applicationName)",
            ],
            shortTitle: "Confirm Income",
            systemImageName: "arrow.down.circle"
        )
    }

    static let shortcutTileColor = ShortcutTileColor.tealGreen
}
