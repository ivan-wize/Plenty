//
//  RootView.swift
//  Plenty
//
//  Target path: Plenty/App/RootView.swift
//
//  Phase 5: tab content + AddActionSheet + pendingAddSheet routing.
//  Phase 6: + StoreKit init.
//  Phase 7: + Subscription detection runner, notification rescheduling,
//           subscription reminder sync, weekly Read pre-generation.
//

import SwiftUI
import SwiftData

struct RootView: View {

    @Environment(AppState.self) private var appState
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(NotificationManager.self) private var notifications
    @Environment(SubscriptionReminderManager.self) private var subscriptionReminders

    @Environment(\.modelContext) private var modelContext

    @State private var showingAddSheet = false
    @State private var readCache = TheReadCache()

    var body: some View {
        @Bindable var state = appState

        tabContent
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                LiquidGlassTabBar(
                    selectedTab: $state.selectedTab,
                    onAddTapped: { showingAddSheet = true }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            .sheet(isPresented: $showingAddSheet) {
                AddActionSheet(
                    onAddExpense: {
                        state.pendingAddSheet = .expense
                    },
                    onAddIncome: {
                        state.pendingAddSheet = .income(preferRecurring: false)
                    },
                    onAddBill: {
                        state.pendingAddSheet = .bill()
                    }
                )
            }
            .sheet(item: $state.pendingAddSheet) { kind in
                pendingSheetView(for: kind)
            }
            .task {
                await runLaunchTasks()
            }
    }

    // MARK: - Launch Tasks

    private func runLaunchTasks() async {
        // 1. StoreKit (Phase 6)
        await storeKit.refreshEntitlements()
        await storeKit.loadProduct()

        // 2. Notifications (Phase 7)
        await notifications.refreshAuthorizationStatus()

        // 3. Subscription detection (Phase 7) — cheap, run once per launch
        let runner = SubscriptionDetectionRunner(modelContext: modelContext)
        await runner.run()

        // 4. Sync EventKit reminders for marked subscriptions (Phase 7)
        if notifications.subscriptionRemindersEnabled {
            let subs = (try? modelContext.fetch(FetchDescriptor<Subscription>())) ?? []
            await subscriptionReminders.syncReminders(for: subs)
        }

        // 5. Schedule notifications based on current data (Phase 7)
        await scheduleNotifications()
    }

    /// Refreshes weekly Read and re-schedules all UNNotifications.
    private func scheduleNotifications() async {
        guard notifications.authorizationStatus == .authorized else { return }

        // Compute current snapshot for the weekly Read.
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
        case .home:     HomeTab()
        case .accounts: AccountsTab()
        case .plan:     PlanTab()
        case .settings: SettingsTab()
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
