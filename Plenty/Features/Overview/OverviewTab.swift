//
//  OverviewTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/OverviewTab.swift
//
//  Phase 2.1 (post-launch v1): the navigation title is cleared.
//  MonthNavigator owns the month label below the nav bar; the nav
//  bar shows only the info button and the settings button. Resolves
//  the duplicated "April 2026" between the inline title and the
//  MonthNavigator.
//
//  Phase 2.2 (post-launch v1): AddFloatingButton no longer lives in
//  this view's ZStack — it's an overlay on RootView. The bottom-
//  trailing ZStack alignment, the FAB padding, and the surrounding
//  ZStack are removed. Just the ScrollView remains.
//
//  Phase 2.4 (post-launch v1): the snapshot is cached in `@State`
//  and refreshed via `.task(id:)` keyed on a hash of inputs that
//  meaningfully affect BudgetEngine.calculate. This avoids
//  recomputing the snapshot on every body re-render — pure
//  state-driven re-renders (e.g., toggling showingExplainer) now
//  reuse the cached value.
//
//  Cache invalidation captures: month, year, transaction count +
//  max updatedAt, account count + balance sum, goal count. Edits to
//  account fields beyond `balance` (e.g., statementBalance) don't
//  invalidate; in practice those edits are rare and the next month
//  navigation refreshes everything. If TestFlight surfaces a
//  staleness symptom, expand SnapshotKey to hash more account
//  fields.
//
//  Phase 3.2 (post-launch v1): hosts the share-this-month sheet.
//  OverviewTopBar's ellipsis menu writes `showingShareSheet`; this
//  view presents `MonthlySharePreviewSheet` with the active month
//  label and the cached snapshot.
//
//  ----- Earlier history -----
//
//  Phase 1.1 (post-launch v1): branches between the populated hero
//  block and OverviewEmptyHero based on
//  `BudgetEngine.hasAnySetupData(...)`.
//
//  Phase 3 (v2): the full Overview tab.
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
    @Query private var allIncomeSources: [IncomeSource]
    @Query private var allSavingsGoals: [SavingsGoal]

    // MARK: - Local State

    @State private var readCache = TheReadCache()
    @State private var showingExplainer = false
    @State private var showingShareSheet = false

    /// Cached snapshot. Refreshed via `.task(id: snapshotKey)` so the
    /// expensive BudgetEngine.calculate path runs once per
    /// meaningful-input change, not once per body render.
    @State private var cachedSnapshot: PlentySnapshot = .empty

    // MARK: - Derived

    /// Drives the empty-state branch. True the moment any account,
    /// transaction, income source, or savings goal exists.
    private var hasAnySetupData: Bool {
        BudgetEngine.hasAnySetupData(
            accounts: allAccounts,
            transactions: allTransactions,
            incomeSources: allIncomeSources,
            savingsGoals: allSavingsGoals
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
            ScrollView {
                VStack(spacing: 24) {
                    ErrorBanner(error: $state.lastError)

                    DemoModeBanner()

                    MonthNavigator()
                        .padding(.horizontal, 8)

                    if hasAnySetupData {
                        populatedContent
                    } else {
                        OverviewEmptyHero()
                    }

                    // Bottom padding to clear the floating tab bar
                    // and the FAB (now hosted by RootView).
                    Color.clear.frame(height: 100)
                }
                .padding(.top, 4)
                .animation(.snappy, value: hasAnySetupData)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            // Phase 2.1: nav title cleared. MonthNavigator below owns
            // the month label; the nav bar carries only the info and
            // settings buttons.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                OverviewTopBar(
                    showingExplainer: $showingExplainer,
                    showingShareSheet: $showingShareSheet,
                    canShare: hasAnySetupData
                )
            }
            .sheet(isPresented: $showingExplainer) {
                AppExplainerSheet()
            }
            .sheet(isPresented: $showingShareSheet) {
                MonthlySharePreviewSheet(
                    monthLabel: monthScope.displayLabel,
                    snapshot: cachedSnapshot
                )
            }
            // Phase 2.4: refresh the cached snapshot whenever the
            // inputs that meaningfully affect it change. `.task(id:)`
            // runs on first appear with the initial id and on every
            // id change thereafter.
            .task(id: snapshotKey) {
                cachedSnapshot = computeSnapshot()
            }
            // Refresh The Read when the scoped month changes.
            .task(id: scopeKey) {
                guard hasAnySetupData else { return }
                await readCache.ensureFresh(snapshot: cachedSnapshot)
            }
            .onChange(of: cachedSnapshot.monthlyBudgetRemaining) { oldValue, newValue in
                // Invalidate The Read when the hero crosses a meaningful
                // boundary (sign change, or > $50 delta).
                guard hasAnySetupData else { return }
                let crossedZero = (oldValue >= 0) != (newValue >= 0)
                let bigSwing = abs(NSDecimalNumber(decimal: oldValue - newValue).doubleValue) > 50
                if crossedZero || bigSwing {
                    Task { await readCache.regenerate(snapshot: cachedSnapshot) }
                }
            }
        }
    }

    // MARK: - Populated Content

    @ViewBuilder
    private var populatedContent: some View {
        VStack(spacing: 6) {
            HeroNumberView(snapshot: cachedSnapshot)
                .currencyDynamicTypeCap()

            ProjectionLineView(snapshot: cachedSnapshot)
                .animation(.snappy, value: cachedSnapshot.expectedIncomeRemaining)
        }

        if let read = readCache.current, read.shouldDisplay {
            TheReadView(read: read, isLoading: readCache.isGenerating)
                .padding(.horizontal, 16)
        }

        OverviewTransactionsSection(transactions: recentTransactions)
            .padding(.horizontal, 16)

        OverviewBillsSection(bills: upcomingBills)
            .padding(.horizontal, 16)
    }

    // MARK: - Snapshot Caching

    private func computeSnapshot() -> PlentySnapshot {
        BudgetEngine.calculate(
            accounts: AccountDerivations.activeAccounts(allAccounts),
            transactions: allTransactions,
            savingsGoals: allSavingsGoals,
            month: monthScope.month,
            year: monthScope.year
        )
    }

    /// Hashable signature of the inputs to BudgetEngine.calculate.
    /// Recomputed every body render (cheap — linear over arrays) and
    /// drives `.task(id:)` to refresh the cache only on real change.
    private var snapshotKey: SnapshotKey {
        SnapshotKey(
            month: monthScope.month,
            year: monthScope.year,
            txCount: allTransactions.count,
            txMaxUpdated: allTransactions.map(\.updatedAt).max() ?? .distantPast,
            acctCount: allAccounts.count,
            acctBalanceSum: allAccounts.reduce(Decimal.zero) { $0 + $1.balance },
            goalCount: allSavingsGoals.count
        )
    }

    private struct SnapshotKey: Hashable {
        let month: Int
        let year: Int
        let txCount: Int
        let txMaxUpdated: Date
        let acctCount: Int
        let acctBalanceSum: Decimal
        let goalCount: Int
    }

    /// Composite key for The Read's `task(id:)` so it re-runs when the
    /// user steps to a new month.
    private var scopeKey: Int {
        monthScope.year * 100 + monthScope.month
    }
}
