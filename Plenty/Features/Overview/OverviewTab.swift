//
//  OverviewTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/OverviewTab.swift
//
//  Phase 3 (v2): the full Overview tab.
//
//  Layout, top to bottom:
//    1. NavigationStack toolbar — info button (left), settings (right)
//    2. ErrorBanner (when AppState has a lastError)
//    3. DemoModeBanner (when demo mode active)
//    4. MonthNavigator
//    5. HeroNumberView — reads `monthlyBudgetRemaining`
//    6. ProjectionLineView — "+ $X expected this month"
//    7. TheReadView — daily AI insight
//    8. OverviewTransactionsSection — last 3 transactions for the month
//    9. OverviewBillsSection — next 3 unpaid bills for the month
//   10. AddFloatingButton — bottom-right, overlays the scroll view
//
//  Data flow:
//    • SwiftData @Queries fetch all accounts / transactions / goals.
//    • BudgetEngine.calculate() runs against the env-injected
//      MonthScope's month + year, so changing the month triggers a
//      full re-render with the new snapshot.
//    • TheReadCache is per-tab @State; it auto-refreshes when the
//      month or hero number changes.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "overview")

struct OverviewTab: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(MonthScope.self) private var monthScope

    // MARK: - Queries

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]
    @Query private var allTransactions: [Transaction]
    @Query private var allSavingsGoals: [SavingsGoal]

    // MARK: - Local State

    @State private var readCache = TheReadCache()
    @State private var showingExplainer = false

    // MARK: - Derived

    private var snapshot: PlentySnapshot {
        BudgetEngine.calculate(
            accounts: AccountDerivations.activeAccounts(allAccounts),
            transactions: allTransactions,
            savingsGoals: allSavingsGoals,
            month: monthScope.month,
            year: monthScope.year
        )
    }

    /// Last three expense or transfer transactions for the scoped month,
    /// newest first. Bills get their own section below.
    private var recentTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions
            .filter { tx in
                guard tx.kind == .expense || tx.kind == .transfer else { return false }
                let m = cal.component(.month, from: tx.date)
                let y = cal.component(.year, from: tx.date)
                return m == monthScope.month && y == monthScope.year
            }
            .sorted { $0.date > $1.date }
            .prefix(3)
            .map { $0 }
    }

    /// Up to three unpaid bills for the scoped month, due-day ascending.
    private var upcomingBills: [Transaction] {
        TransactionProjections.bills(
            allTransactions,
            month: monthScope.month,
            year: monthScope.year
        )
        .filter { !$0.isPaid }
        .sorted { $0.dueDay < $1.dueDay }
        .prefix(3)
        .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 24) {
                        ErrorBanner(error: $state.lastError)

                        DemoModeBanner()

                        MonthNavigator()
                            .padding(.horizontal, 8)

                        VStack(spacing: 6) {
                            HeroNumberView(snapshot: snapshot)
                                .currencyDynamicTypeCap()

                            ProjectionLineView(snapshot: snapshot)
                                .animation(.snappy, value: snapshot.expectedIncomeRemaining)
                        }

                        if let read = readCache.current, read.shouldDisplay {
                            TheReadView(read: read, isLoading: readCache.isGenerating)
                                .padding(.horizontal, 16)
                        }

                        OverviewTransactionsSection(transactions: recentTransactions)
                            .padding(.horizontal, 16)

                        OverviewBillsSection(bills: upcomingBills)
                            .padding(.horizontal, 16)

                        // Bottom padding to clear the floating tab bar
                        // and the FAB.
                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 4)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Theme.background)

                AddFloatingButton()
                    .padding(.trailing, 20)
                    .padding(.bottom, 84)  // clears the floating tab bar
            }
            .navigationTitle(monthScope.displayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                OverviewTopBar(showingExplainer: $showingExplainer)
            }
            .sheet(isPresented: $showingExplainer) {
                AppExplainerSheet()
            }
            // Refresh The Read when the scoped month changes.
            .task(id: scopeKey) {
                await readCache.ensureFresh(snapshot: snapshot)
            }
            .onChange(of: snapshot.monthlyBudgetRemaining) { oldValue, newValue in
                // Invalidate The Read when the hero crosses a meaningful
                // boundary (sign change, or > $50 delta).
                let crossedZero = (oldValue >= 0) != (newValue >= 0)
                let bigSwing = abs(NSDecimalNumber(decimal: oldValue - newValue).doubleValue) > 50
                if crossedZero || bigSwing {
                    Task { await readCache.regenerate(snapshot: snapshot) }
                }
            }
        }
    }

    /// Composite key for The Read's `task(id:)` so it re-runs when the
    /// user steps to a new month.
    private var scopeKey: Int {
        monthScope.year * 100 + monthScope.month
    }
}
