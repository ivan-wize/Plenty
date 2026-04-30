//
//  TransactionsListView.swift
//  Plenty
//
//  Target path: Plenty/Features/Expenses/Transactions/TransactionsListView.swift
//
//  Phase 2.5 (post-launch v1): adds search and category filter.
//
//    • `.searchable(text: $searchText)` — matches transaction name
//      OR category display name (case-insensitive). Lives in the
//      parent NavigationStack's drawer; iOS reveals it on pull-down
//      and keeps it pinned during scroll.
//
//    • Toolbar Menu with Picker bound to `categoryFilter`. The
//      picker is sectioned (Expenses / Transfers) since this view
//      shows expense + transfer kinds; income lives on its own tab.
//      The chip glyph switches to its `.fill` variant when a filter
//      is active.
//
//  Three-state empty handling:
//
//    1. No transactions in this month at all       → original empty
//    2. Transactions exist but search/filter empty → "No matches"
//    3. Otherwise                                  → list
//
//  The "Spent this month" total is intentionally NOT filtered. It
//  remains a stable read of the full month's spending so users have
//  a ground-truth number while exploring filter views. If you want
//  the filtered total, you can read it off the row sum directly.
//
//  ----- Earlier history -----
//
//  Phase 5 (v2): month-scoped transactions list shown inside the
//  Expenses tab's Transactions sub-tab.
//
//  Filters in this view:
//    • Month: from MonthScope
//    • Kind:  expense + transfer (income lives in the Income tab,
//             bills in the Bills sub-tab)
//

import SwiftUI
import SwiftData

struct TransactionsListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(MonthScope.self) private var monthScope

    @Query private var allTransactions: [Transaction]

    @State private var transactionToEdit: Transaction?
    @State private var searchText: String = ""
    @State private var categoryFilter: TransactionCategory? = nil

    // MARK: - Derived

    /// Month + kind filter. The base list before search/category filters.
    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions
            .filter { tx in
                guard tx.kind == .expense || tx.kind == .transfer else { return false }
                let m = cal.component(.month, from: tx.date)
                let y = cal.component(.year, from: tx.date)
                return m == monthScope.month && y == monthScope.year
            }
            .sorted { $0.date > $1.date }
    }

    /// Apply the user's search text and category filter on top of the
    /// month-scoped list.
    private var filteredTransactions: [Transaction] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return monthTransactions.filter { tx in
            if let categoryFilter, tx.category != categoryFilter {
                return false
            }
            if !trimmedSearch.isEmpty {
                let nameMatch = tx.name.lowercased().contains(trimmedSearch)
                let categoryMatch = tx.category?.displayName.lowercased().contains(trimmedSearch) ?? false
                if !(nameMatch || categoryMatch) { return false }
            }
            return true
        }
    }

    /// Full-month expense total — stable across filter changes.
    private var expensesTotal: Decimal {
        monthTransactions
            .filter { $0.kind == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var isFilterActive: Bool {
        categoryFilter != nil ||
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        Group {
            if monthTransactions.isEmpty {
                emptyState
            } else if filteredTransactions.isEmpty {
                noMatchesState
            } else {
                populated
            }
        }
        .searchable(text: $searchText, prompt: Text("Search transactions"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                categoryFilterMenu
            }
        }
        .sheet(item: $transactionToEdit) { tx in
            AddExpenseSheet(existing: tx)
        }
    }

    // MARK: - Populated

    private var populated: some View {
        List {
            Section {
                ForEach(filteredTransactions) { tx in
                    TransactionRow(transaction: tx)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Only expenses are editable; transfers are
                            // edited via the Accounts pane in P6.
                            if tx.kind == .expense {
                                transactionToEdit = tx
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(tx)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Spent this month")
                    Spacer()
                    Text(expensesTotal.asPlainCurrency())
                        .monospacedDigit()
                }
            } footer: {
                Text(footerText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private var footerText: String {
        if isFilterActive {
            let count = filteredTransactions.count
            return "Showing \(count) of \(monthTransactions.count) this month."
        }
        return "Tap a transaction to edit. Swipe to delete."
    }

    // MARK: - Empty States

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No transactions yet", systemImage: "creditcard")
                .foregroundStyle(Theme.sage)
        } description: {
            Text("Tap + below to add an expense, or scan a receipt.")
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 60)
    }

    private var noMatchesState: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "magnifyingglass")
                .foregroundStyle(Theme.sage)
        } description: {
            Text(noMatchesDescription)
                .multilineTextAlignment(.center)
        } actions: {
            Button {
                clearFilters()
            } label: {
                Text("Clear filters")
                    .font(Typography.Body.emphasis)
            }
            .buttonStyle(.bordered)
            .tint(Theme.sage)
        }
        .padding(.bottom, 60)
    }

    private var noMatchesDescription: String {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (trimmedSearch.isEmpty, categoryFilter) {
        case (false, .some(let cat)):
            return "Nothing in \(cat.displayName) matches \"\(trimmedSearch)\" this month."
        case (false, .none):
            return "Nothing this month matches \"\(trimmedSearch)\"."
        case (true, .some(let cat)):
            return "No \(cat.displayName) transactions this month."
        case (true, .none):
            return "Nothing here." // Should never hit — guarded by isFilterActive above.
        }
    }

    // MARK: - Filter Menu

    private var categoryFilterMenu: some View {
        Menu {
            Picker("Category", selection: $categoryFilter) {
                Text("All categories").tag(TransactionCategory?.none)
                Section("Expenses") {
                    ForEach(TransactionCategory.expenseCases, id: \.self) { cat in
                        Text(cat.displayName).tag(TransactionCategory?.some(cat))
                    }
                }
                Section("Transfers") {
                    ForEach(TransactionCategory.transferCases, id: \.self) { cat in
                        Text(cat.displayName).tag(TransactionCategory?.some(cat))
                    }
                }
            }
        } label: {
            Image(systemName: filterGlyph)
                .font(.body)
                .foregroundStyle(Theme.sage)
        }
        .accessibilityLabel(categoryFilter.map { "Filter: \($0.displayName)" } ?? "Filter by category")
    }

    private var filterGlyph: String {
        categoryFilter == nil
            ? "line.3.horizontal.decrease.circle"
            : "line.3.horizontal.decrease.circle.fill"
    }

    // MARK: - Actions

    private func delete(_ tx: Transaction) {
        modelContext.delete(tx)
        try? modelContext.save()
    }

    private func clearFilters() {
        searchText = ""
        categoryFilter = nil
    }
}

// MARK: - Decimal Helper

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
