//
//  PlentyTimelineProvider.swift
//  Plenty
//
//  Target path: PlentyWidget/PlentyTimelineProvider.swift
//  Widget target: PlentyWidget extension
//
//  Reads from the App Group SwiftData container, computes the current
//  PlentySnapshot via BudgetEngine, and returns a single-entry
//  timeline that refreshes every 30 minutes.
//
//  30 minutes is the right cadence for a budget number: fresh enough
//  to feel responsive when the user updates a balance or adds a
//  transaction, sparse enough to leave plenty of widget refresh
//  budget for other apps.
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

            // Refresh every 30 minutes, or at midnight if sooner (for
            // the "next income date" countdown to roll over correctly).
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
        // Without this, a widget viewed early in a month before the user
        // opens the app might not see expected paychecks.
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
            spendable: snapshot.spendable,
            zone: snapshot.zone,
            cashOnHand: snapshot.cashOnHand,
            sustainableDailyBurn: snapshot.sustainableDailyBurn,
            billsRemaining: snapshot.billsRemaining,
            billsRemainingCount: snapshot.billsTotalCount - snapshot.billsPaidCount,
            nextBillName: nextBill?.name,
            nextBillAmount: nextBill?.amount,
            nextBillDueDay: nextBill?.dueDay,
            nextIncomeDate: snapshot.nextIncomeDate,
            hasAnyData: hasAnyData,
            isPlaceholder: false,
            isUnavailable: false
        )
    }
}
