//
//  PlentyShortcutsProvider.swift
//  Plenty
//
//  Target path: Plenty/Intents/PlentyShortcutsProvider.swift
//
//  Phase 8 (v2): Siri trigger phrases updated to v2 vocabulary.
//  "What's my spendable" → "What's my budget" / "What's left this
//  month." Old phrases kept alongside new ones for muscle-memory
//  continuity.
//
//  Read intents (P4):
//    • GetPlentyIntent          — "How much do I have?"
//    • MonthlySummaryIntent     — "Plenty monthly summary"
//    • SpendingBreakdownIntent  — "Show my spending breakdown"
//
//  Write intents (P7):
//    • AddExpenseIntent         — "Add expense in Plenty"
//    • AddIncomeIntent          — "Log income in Plenty"
//    • AddBillIntent            — "Add bill in Plenty"
//    • MarkBillPaidIntent       — "Mark bill paid in Plenty"
//    • LogSavingsIntent         — "Log savings in Plenty"
//    • ConfirmIncomeIntent      — "Confirm my paycheck"
//

import AppIntents

struct PlentyShortcutsProvider: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {

        // Read intents

        AppShortcut(
            intent: GetPlentyIntent(),
            phrases: [
                "How much do I have in \(.applicationName)",
                "What's my budget in \(.applicationName)",
                "What's left in \(.applicationName)",
                "What's left this month in \(.applicationName)",
                "Check \(.applicationName)",
            ],
            shortTitle: "Check Budget",
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

        // Write intents

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
            ],
            shortTitle: "Mark Bill Paid",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: LogSavingsIntent(),
            phrases: [
                "Log savings in \(.applicationName)",
            ],
            shortTitle: "Log Savings",
            systemImageName: "leaf"
        )

        AppShortcut(
            intent: ConfirmIncomeIntent(),
            phrases: [
                "Confirm my paycheck in \(.applicationName)",
            ],
            shortTitle: "Confirm Income",
            systemImageName: "checkmark.seal"
        )
    }
}
