//
//  PlentyTimelineProvider.swift
//  Plenty
//
//  Target path: PlentyWidget/PlentyTimelineProvider.swift
//  Widget target: PlentyWidget extension
//
//  Phase 8 (v2): populates the v2 PlentyEntry from the current
//  PlentySnapshot. Reads `snapshot.monthlyBudgetRemaining` for the
//  hero number and `snapshot.expectedIncomeRemaining` for the
//  optional projection line.
//
//  Refresh cadence is unchanged from v1: 30 minutes, or sooner if
//  midnight is closer (so day-based projections roll over).
//

import Foundation
import WidgetKit
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "widget")

struct PlentyTimelineProvider: TimelineProvider {

    // MARK: - TimelineProvider

    func placeholder(in context: Context) -> PlentyEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (PlentyEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { @MainActor in
            completion(await fetchEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlentyEntry>) -> Void) {
        Task { @MainActor in
            let entry = await fetchEntry()

            // Refresh every 30 minutes, or at midnight if sooner.
            let cal = Calendar.current
            let in30Min = Date.now.addingTimeInterval(30 * 60)
            let nextMidnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: .now)!)
            let refresh = min(in30Min, nextMidnight)

            let timeline = Timeline(entries: [entry], policy: .after(refresh))
            completion(timeline)
        }
    }

    // MARK: - Fetch

    @MainActor
    private func fetchEntry() async -> PlentyEntry {
        guard let container = ModelContainerFactory.makeForWidget() else {
            logger.warning("Widget could not open SwiftData container.")
            return .unavailable
        }

        let context = container.mainContext

        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<SavingsGoal>())) ?? []

        let activeAccounts = AccountDerivations.activeAccounts(accounts)

        let cal = Calendar.current
        let now = Date.now
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)

        // Materialize expected income for current month idempotently.
        // Without this, a widget viewed early in a month before the
        // user opens the app might not see expected paychecks.
        try? IncomeEntryGenerator(context: context).prepareExpectedEntries(month: m, year: y)

        let snapshot = BudgetEngine.calculate(
            accounts: activeAccounts,
            transactions: transactions,
            savingsGoals: goals,
            month: m,
            year: y
        )

        let monthBills = TransactionProjections.bills(transactions, month: m, year: y)
            .filter { !$0.isPaid }
            .sorted { $0.dueDay < $1.dueDay }
        let nextBill = monthBills.first

        let hasAnyData = !accounts.isEmpty || !transactions.isEmpty

        return PlentyEntry(
            date: now,
            monthlyBudgetRemaining: snapshot.monthlyBudgetRemaining,
            cashOnHand: snapshot.cashOnHand,
            sustainableDailyBurn: snapshot.sustainableDailyBurn,
            billsRemaining: snapshot.billsRemaining,
            billsRemainingCount: snapshot.billsTotalCount - snapshot.billsPaidCount,
            nextBillName: nextBill?.name,
            nextBillAmount: nextBill?.amount,
            nextBillDueDay: nextBill?.dueDay,
            nextIncomeDate: snapshot.nextIncomeDate,
            expectedIncomeRemaining: snapshot.expectedIncomeRemaining,
            hasAnyData: hasAnyData,
            isPlaceholder: false,
            isUnavailable: false
        )
    }
}
