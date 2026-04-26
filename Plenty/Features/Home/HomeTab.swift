//
//  HomeTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/HomeTab.swift
//
//  Phase 4: real Home tab with hero, Read, glance, accounts, checklist.
//  Phase 5 update: wired Add sheet callbacks via AppState.pendingAddSheet.
//  Phase 10 update: + ErrorBanner at top, dynamic type cap on hero.
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "home")

struct HomeTab: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Account.sortOrder)
    private var allAccounts: [Account]

    @Query private var allTransactions: [Transaction]
    @Query private var allSavingsGoals: [SavingsGoal]

    @State private var readCache = TheReadCache()

    private var month: Int { Calendar.current.component(.month, from: .now) }
    private var year:  Int { Calendar.current.component(.year,  from: .now) }

    // MARK: - Derived

    private var activeAccounts: [Account] {
        AccountDerivations.activeAccounts(allAccounts)
    }

    private var snapshot: PlentySnapshot {
        BudgetEngine.calculate(
            accounts: activeAccounts,
            transactions: allTransactions,
            savingsGoals: allSavingsGoals,
            month: month,
            year: year
        )
    }

    private var unpaidBills: [Transaction] {
        TransactionProjections.bills(allTransactions, month: month, year: year)
            .filter { !$0.isPaid }
    }

    private var expectedIncome: [Transaction] {
        TransactionProjections.income(allTransactions, month: month, year: year)
            .filter { $0.incomeStatus == .expected }
    }

    private var hasIncomeEverConfigured: Bool {
        let hasSource = (try? modelContext.fetch(
            FetchDescriptor<IncomeSource>(predicate: #Predicate { $0.isActive == true })
        ))?.isEmpty == false
        let hasTransaction = allTransactions.contains { $0.kind == .income }
        return hasSource || hasTransaction
    }

    private var hasCashAccount: Bool {
        AccountDerivations.hasCashAccount(allAccounts)
    }

    private var hasBillsConfigured: Bool {
        allTransactions.contains { $0.kind == .bill }
    }

    // MARK: - Body

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Phase 10: error banner above the hero
                    ErrorBanner(error: $state.lastError)

                    HeroNumberView(snapshot: snapshot)
                        .currencyDynamicTypeCap()

                    TheReadView(
                        read: readCache.current,
                        isLoading: readCache.isGenerating
                    )

                    AccountStripView(accounts: activeAccounts)

                    SetupChecklistView(
                        hasIncome: hasIncomeEverConfigured,
                        hasCashAccount: hasCashAccount,
                        hasBills: hasBillsConfigured,
                        onAddIncome: {
                            appState.pendingAddSheet = .income(preferRecurring: true)
                        },
                        onAddAccount: {
                            appState.pendingAddSheet = .account()
                        },
                        onAddBill: {
                            appState.pendingAddSheet = .bill()
                        }
                    )

                    HomeGlanceSection(
                        bills: unpaidBills,
                        income: expectedIncome,
                        onTapBill: { bill in
                            appState.pendingAddSheet = .bill(existing: bill)
                        },
                        onTapIncome: { income in
                            appState.pendingAddSheet = .confirmIncome(income)
                        }
                    )
                }
                .padding(.vertical, 16)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Wordmark(.callout)
                }
            }
        }
        .task { ensureIncomeEntries() }
        .task { await refreshTheRead() }
    }

    // MARK: - Side Effects

    private func ensureIncomeEntries() {
        do {
            let generator = IncomeEntryGenerator(context: modelContext)
            try generator.prepareExpectedEntries(month: month, year: year)
        } catch {
            logger.error("Income entry generation failed: \(error.localizedDescription)")
        }
    }

    private func refreshTheRead() async {
        await readCache.ensureFresh(snapshot: snapshot)
    }
}
