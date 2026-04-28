//
//  RootView.swift
//  Plenty
//
//  Target path: Plenty/App/RootView.swift
//
//  Phase 0 (v2): four-tab routing, no center Add button, MonthScope
//  reset to the current calendar month on cold launch.
//
//  Changes from v1:
//    • Tab cases: overview / income / expenses / plan (was home /
//      accounts / plan / settings).
//    • LiquidGlassTabBar API drops onAddTapped (the FAB on Overview
//      replaces the center add button — P3).
//    • AddActionSheet presentation removed (file deleted).
//    • Settings sheet hookup added but unused until P3 wires the
//      OverviewTopBar gear button.
//    • MonthScope is reset to "now" once on cold launch so the UI
//      always opens on the current month even if the previous session
//      ended scoped elsewhere.
//
//  Launch tasks (StoreKit, notifications, subscription detection,
//  reminder sync, weekly Read pre-generation) carry over from v1
//  unchanged. The weekly Read generation uses the new BudgetEngine
//  output as soon as P1 lands.
//

import SwiftUI
import SwiftData

struct RootView: View {

    @Environment(AppState.self) private var appState
    @Environment(MonthScope.self) private var monthScope
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(NotificationManager.self) private var notifications
    @Environment(SubscriptionReminderManager.self) private var subscriptionReminders

    @Environment(\.modelContext) private var modelContext

    @State private var readCache = TheReadCache()

    var body: some View {
        @Bindable var state = appState

        tabContent
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                LiquidGlassTabBar(selectedTab: $state.selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
            .sheet(item: $state.pendingAddSheet) { kind in
                pendingSheetView(for: kind)
            }
            .sheet(isPresented: $state.showingSettingsSheet) {
                NavigationStack {
                    SettingsView()
                }
            }
            .task {
                // Reset month scope to the current calendar month on
                // each cold launch. Within a session, the user's
                // navigation persists.
                monthScope.resetToCurrent()

                await runLaunchTasks()
            }
    }

    // MARK: - Launch Tasks

    private func runLaunchTasks() async {
        // 1. StoreKit — refresh entitlements + load product
        await storeKit.refreshEntitlements()
        await storeKit.loadProduct()

        // 2. Notifications — authorization status
        await notifications.refreshAuthorizationStatus()

        // 3. Subscription detection — cheap, run once per launch
        let runner = SubscriptionDetectionRunner(modelContext: modelContext)
        await runner.run()

        // 4. EventKit reminders for marked subscriptions
        if notifications.subscriptionRemindersEnabled {
            let subs = (try? modelContext.fetch(FetchDescriptor<Subscription>())) ?? []
            await subscriptionReminders.syncReminders(for: subs)
        }

        // 5. Schedule notifications based on current data
        await scheduleNotifications()
    }

    /// Refreshes weekly Read and re-schedules all UNNotifications.
    ///
    /// Note: BudgetEngine.calculate is called here with v1 field set;
    /// P1 rewrites the engine to also produce v2 fields. The call site
    /// stays the same.
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
        case .income(let preferRecurring):
            AddIncomeSheet(preferRecurring: preferRecurring)
        case .bill(let existing):
            BillEditorSheet(bill: existing)
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
}
