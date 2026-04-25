//
//  RootView.swift
//  Plenty
//
//  Target path: Plenty/App/RootView.swift
//
//  Phase 5 update: wires the AddActionSheet's three options to real
//  sheets, plus an additional sheet for any other Add request that
//  comes through AppState.pendingAddSheet from elsewhere in the app
//  (HomeTab setup checklist, glance section, AccountDetailView's
//  Update Balance, etc.).
//
//  Two-sheet sequence pattern:
//    1. User taps Add button → showingAddSheet = true → AddActionSheet
//    2. User picks an option → AddActionSheet dismisses, sets
//       appState.pendingAddSheet
//    3. RootView's .sheet(item:) on pendingAddSheet presents the real
//       editor sheet (AddExpenseSheet, etc.)
//

import SwiftUI

struct RootView: View {

    @Environment(AppState.self) private var appState

    @State private var showingAddSheet = false

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
        }
    }
}
