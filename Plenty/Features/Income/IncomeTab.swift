//
//  IncomeTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Income/IncomeTab.swift
//
//  Phase 4 (v2): the full Income tab.
//
//  Layout, top to bottom:
//    1. NavigationStack with `+` toolbar button → AddIncomeSheet
//    2. MonthNavigator — scopes the page to a calendar month
//    3. IncomeMonthSummaryCard — Confirmed / Expected totals
//    4. IncomeListView — Confirmed and Expected sections
//       (or empty-state CTA when nothing for the month)
//    5. "Copy from previous month" button at the bottom of the list
//
//  Data flow:
//    • SwiftData @Query fetches all income transactions
//    • Filter to monthScope's month/year
//    • Split into confirmed / expected groups
//    • CopyFromPreviousMonthSheet pulls from the immediately prior
//      month and materializes selected items as Expected income with
//      `copiedFromID` set on each new Transaction
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "income-tab")

struct IncomeTab: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(MonthScope.self) private var monthScope

    // MARK: - Queries

    @Query private var allTransactions: [Transaction]

    // MARK: - Local State

    @State private var showingCopySheet = false

    // MARK: - Derived

    private var monthIncome: [Transaction] {
        TransactionProjections.income(
            allTransactions,
            month: monthScope.month,
            year: monthScope.year
        )
    }

    private var confirmed: [Transaction] {
        monthIncome
            .filter { $0.incomeStatus == .confirmed }
            .sorted { $0.date > $1.date }
    }

    private var expected: [Transaction] {
        monthIncome
            .filter { $0.incomeStatus == .expected }
            .sorted { $0.date < $1.date }
    }

    private var confirmedTotal: Decimal {
        confirmed.reduce(Decimal.zero) { $0 + ($1.confirmedAmount ?? $1.amount) }
    }

    private var expectedTotal: Decimal {
        expected.reduce(Decimal.zero) { $0 + ($1.expectedAmount > 0 ? $1.expectedAmount : $1.amount) }
    }

    private var previousMonthScope: (month: Int, year: Int) {
        var m = monthScope.month - 1
        var y = monthScope.year
        if m < 1 { m = 12; y -= 1 }
        return (m, y)
    }

    private var previousMonthIncome: [Transaction] {
        TransactionProjections.income(
            allTransactions,
            month: previousMonthScope.month,
            year: previousMonthScope.year
        )
        .sorted { $0.date < $1.date }
    }

    private var previousMonthLabel: String {
        var comps = DateComponents()
        comps.year = previousMonthScope.year
        comps.month = previousMonthScope.month
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return "Previous month" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonthNavigator()
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                if monthIncome.isEmpty {
                    emptyState
                } else {
                    populatedContent
                }
            }
            .background(Theme.background)
            .navigationTitle("Income")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.pendingAddSheet = .income(preferRecurring: false)
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.sage)
                    }
                    .accessibilityLabel("Add income")
                }
            }
            .sheet(isPresented: $showingCopySheet) {
                copySheet
            }
            .task(id: scopeKey) {
                await ensureExpectedEntries()
            }
        }
    }

    // MARK: - Populated Content

    private var populatedContent: some View {
        VStack(spacing: 0) {
            IncomeMonthSummaryCard(
                confirmedTotal: confirmedTotal,
                confirmedCount: confirmed.count,
                expectedTotal: expectedTotal,
                expectedCount: expected.count
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            IncomeListView(confirmed: confirmed, expected: expected)
                .frame(maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if !previousMonthIncome.isEmpty {
                copyFromPreviousButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 84)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                ContentUnavailableView {
                    Label("No income yet this month", systemImage: "arrow.down.circle")
                        .foregroundStyle(Theme.sage)
                } description: {
                    Text("Add a paycheck or bring it forward from last month.")
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                VStack(spacing: 10) {
                    Button {
                        appState.pendingAddSheet = .income(preferRecurring: true)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Add recurring income")
                                .font(Typography.Body.emphasis)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                .fill(Theme.sage)
                        )
                    }
                    .buttonStyle(.plain)

                    if !previousMonthIncome.isEmpty {
                        Button {
                            showingCopySheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Copy from \(previousMonthLabel)")
                                    .font(Typography.Body.emphasis)
                                    .foregroundStyle(Theme.sage)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .stroke(Theme.sage, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Copy Button

    private var copyFromPreviousButton: some View {
        Button {
            showingCopySheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.on.square")
                    .font(.body)
                Text("Copy from \(previousMonthLabel)")
                    .font(Typography.Body.regular)
                Spacer()
            }
            .foregroundStyle(Theme.sage)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Copy Sheet

    @ViewBuilder
    private var copySheet: some View {
        CopyFromPreviousMonthSheet<Transaction>(
            title: "Copy income",
            subtitle: "Bringing forward entries from \(previousMonthLabel).",
            sourceItems: previousMonthIncome,
            summarize: { tx in
                CopyItemSummary(
                    name: tx.name,
                    defaultAmount: tx.expectedAmount > 0 ? tx.expectedAmount : tx.amount,
                    secondary: tx.incomeSource?.frequency.displayName
                )
            },
            onCopy: { selections in
                applyCopiedIncome(selections)
            }
        )
    }

    // MARK: - Actions

    private func applyCopiedIncome(_ selections: [CopySelection<Transaction>]) {
        let cal = Calendar.current

        for selection in selections {
            let original = selection.source
            let originalDay = cal.component(.day, from: original.date)

            // Build a date in the current scoped month, clamping the
            // day to the month's length (e.g. 31 → 28 in February).
            let monthLen = cal.range(
                of: .day,
                in: .month,
                for: cal.date(from: DateComponents(year: monthScope.year, month: monthScope.month, day: 1)) ?? .now
            )?.count ?? 28

            let targetDay = min(originalDay, monthLen)
            let targetDate = cal.date(from: DateComponents(
                year: monthScope.year,
                month: monthScope.month,
                day: targetDay
            )) ?? .now

            let newTx: Transaction
            if let source = original.incomeSource {
                newTx = Transaction.expectedIncome(
                    name: original.name,
                    expectedAmount: selection.amount,
                    date: targetDate,
                    source: source
                )
            } else {
                // One-time income with no source: copy as a fresh
                // expected entry without a source link.
                newTx = Transaction(
                    kind: .income,
                    name: original.name,
                    amount: selection.amount,
                    date: targetDate,
                    month: monthScope.month,
                    year: monthScope.year,
                    expectedAmount: selection.amount,
                    incomeStatus: .expected
                )
            }

            newTx.copiedFromID = original.id
            modelContext.insert(newTx)
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Copy income save failed: \(error.localizedDescription)")
        }
    }

    private func ensureExpectedEntries() async {
        do {
            try IncomeEntryGenerator(context: modelContext)
                .prepareExpectedEntries(month: monthScope.month, year: monthScope.year)
        } catch {
            logger.error("ensureExpectedEntries failed: \(error.localizedDescription)")
        }
    }

    private var scopeKey: Int {
        monthScope.year * 100 + monthScope.month
    }
}
