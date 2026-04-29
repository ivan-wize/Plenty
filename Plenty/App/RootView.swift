//
//  RootView.swift
//  Plenty
//
//  Target path: Plenty/App/RootView.swift
//
//  Build fix:
//    • Corrected `SubscriptionRemindersService` → `SubscriptionReminderManager`.
//      The actual class name is singular and ends in "Manager" — see
//      Plenty/Notifications/SubscriptionReminderManager.swift. P5's
//      RootView used the wrong name and it carried through to P10.
//    • Pass `selectedTab: $state.selectedTab` to LiquidGlassTabBar.
//      v2's tab bar exposes `@Binding var selectedTab: AppState.Tab`
//      and was missing its argument here.
//
//  Otherwise unchanged from P10: the pending-sheet router handles the
//  scan-driven cases, the `.billFromScan` route drops the image arg
//  since BillEditorSheet doesn't accept one, etc.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "root-view")

struct RootView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Environment(AppState.self) private var appState
    @Environment(MonthScope.self) private var monthScope
    @Environment(NotificationManager.self) private var notifications
    @Environment(SubscriptionReminderManager.self) private var subscriptionReminders
    @Environment(StoreKitManager.self) private var storeKit

    @State private var readCache = TheReadCache()

    // MARK: - Body

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .bottom) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LiquidGlassTabBar(selectedTab: $state.selectedTab)
                .padding(.bottom, 8)
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $state.pendingAddSheet) { kind in
            pendingSheetView(for: kind)
        }
        .sheet(isPresented: $state.showingSettingsSheet) {
            SettingsView()
        }
        .task {
            await runStartupTasks()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await scheduleNotifications() }
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch appState.selectedTab {
        case .overview: OverviewTab()
        case .income:   IncomeTab()
        case .expenses: ExpensesTab()
        case .plan:     PlanTab()
        }
    }

    // MARK: - Pending Sheet Router

    @ViewBuilder
    private func pendingSheetView(for kind: AppState.PendingAddSheet) -> some View {
        switch kind {
        case .expense:
            AddExpenseSheet()

        case .expenseFromScan(let draft, let image):
            AddExpenseSheet(initialDraft: draft, initialImage: image)

        case .income(let preferRecurring):
            AddIncomeSheet(preferRecurring: preferRecurring)

        case .bill(let existing):
            BillEditorSheet(bill: existing)

        case .billFromScan(let draft, _):
            // The image arg is intentionally dropped — bills don't have
            // a model field for it yet. The draft alone is what fills
            // the form. v2.1 follow-up: wire `Transaction.billImageData`
            // and re-introduce the image parameter.
            BillEditorSheet(billDraft: draft)

        case .account(let existing):
            AddAccountSheet(account: existing)

        case .updateBalance(let account):
            UpdateBalanceSheet(account: account)

        case .confirmIncome(let transaction):
            ConfirmIncomeSheet(transaction: transaction)

        case .subscription:
            AddSubscriptionSheet()

        case .savingsGoal(let existing):
            AddSavingsGoalSheet(goal: existing)

        case .logContribution(let goal):
            LogContributionSheet(goal: goal)
        }
    }

    // MARK: - Startup

    private func runStartupTasks() async {
        // 1. Income-entry generation for the current month
        do {
            let cal = Calendar.current
            let now = Date.now
            let m = cal.component(.month, from: now)
            let y = cal.component(.year, from: now)
            try IncomeEntryGenerator(context: modelContext)
                .prepareExpectedEntries(month: m, year: y, includeInactiveSourceCleanup: true)
        } catch {
            logger.error("Startup income generation failed: \(error.localizedDescription)")
        }

        // 2. Sync Pro entitlement
        await storeKit.refreshEntitlements()

        // 3. Notifications authorization sync
        await notifications.refreshAuthorizationStatus()

        // 4. Sync EventKit reminders for marked subscriptions
        if notifications.subscriptionRemindersEnabled {
            let subs = (try? modelContext.fetch(FetchDescriptor<Subscription>())) ?? []
            await subscriptionReminders.syncReminders(for: subs)
        }

        // 5. Schedule notifications based on current data
        await scheduleNotifications()
    }

    /// Refreshes weekly Read and re-schedules all UNNotifications.
    private func scheduleNotifications() async {
        guard notifications.authorizationStatus == .authorized else { return }

        let accounts = (try? modelContext.fetch(FetchDescriptor<Account>())) ?? []
        let transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let goals = (try? modelContext.fetch(FetchDescriptor<SavingsGoal>())) ?? []

        let cal = Calendar.current
        let now = Date.now
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)

        let snapshot = BudgetEngine.calculate(
            accounts: AccountDerivations.activeAccounts(accounts),
            transactions: transactions,
            savingsGoals: goals,
            month: m,
            year: y
        )

        if notifications.weeklyReadEnabled {
            await readCache.ensureFreshWeekly(snapshot: snapshot)
        }

        let scheduler = NotificationScheduler(
            manager: notifications,
            modelContext: modelContext
        )
        await scheduler.rescheduleAll(snapshot: snapshot, weeklyRead: readCache.weeklyCurrent)
    }
}
