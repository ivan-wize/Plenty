//
//  TrendsView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/TrendsView.swift
//
//  The Trends mode of the Plan tab. Two visualizations:
//
//    1. NetWorthTrendChart — 6 months of net worth line.
//    2. Spending Breakdown — current month's expenses by category,
//       sorted descending. Reuses TransactionProjections logic.
//

import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {

    @Query(sort: \Account.sortOrder)
    private var allAccounts: [Account]

    @Query private var allTransactions: [Transaction]

    private var month: Int { Calendar.current.component(.month, from: .now) }
    private var year:  Int { Calendar.current.component(.year,  from: .now) }

    private var spendingBreakdown: [CategoryBreakdown] {
        let bills = TransactionProjections.bills(allTransactions, month: month, year: year)
        let expenses = TransactionProjections.expenses(allTransactions, month: month, year: year)
        return TransactionProjections.categoryBreakdown(bills: bills, expenses: expenses)
    }

    private var totalSpending: Decimal {
        spendingBreakdown.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var hasAnyData: Bool {
        !allAccounts.isEmpty || !spendingBreakdown.isEmpty
    }

    // MARK: - Body

    var body: some View {
        if !hasAnyData {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    if !allAccounts.isEmpty {
                        NetWorthTrendChart(accounts: allAccounts)
                            .padding(.horizontal, 16)
                    }

                    if !spendingBreakdown.isEmpty {
                        spendingCard
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Spending Card

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spending This Month")
                    .font(Typography.Title.small)

                Text("\(totalSpending.asPlainCurrency()) total across \(spendingBreakdown.count) \(spendingBreakdown.count == 1 ? "category" : "categories")")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }

            if spendingBreakdown.count >= 2 {
                donut
                    .frame(height: 180)
            }

            VStack(spacing: 12) {
                ForEach(spendingBreakdown) { item in
                    breakdownRow(item)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Donut

    private var donut: some View {
        Chart(spendingBreakdown) { item in
            SectorMark(
                angle: .value("Amount", (item.amount as NSDecimalNumber).doubleValue),
                innerRadius: .ratio(0.62),
                angularInset: 2
            )
            .foregroundStyle(by: .value("Category", item.displayName))
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .chartForegroundStyleScale(range: donutColors)
    }

    private var donutColors: [Color] {
        // Sage tints decreasing in saturation. Avoids amber/terracotta
        // which are reserved for state communication elsewhere.
        [
            Theme.sage,
            Theme.sage.opacity(0.85),
            Theme.sage.opacity(0.7),
            Theme.sage.opacity(0.55),
            Theme.sage.opacity(0.4),
            Theme.sage.opacity(0.25),
        ]
    }

    // MARK: - Breakdown Row

    private func breakdownRow(_ item: CategoryBreakdown) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .font(.body)
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

            Text(item.displayName)
                .font(Typography.Body.regular)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.amount.asPlainCurrency())
                    .font(Typography.Body.emphasis.monospacedDigit())
                Text(percentageLabel(for: item))
                    .font(Typography.Support.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }

    private func percentageLabel(for item: CategoryBreakdown) -> String {
        guard totalSpending > 0 else { return "0%" }
        let fraction = (item.amount / totalSpending as NSDecimalNumber).doubleValue
        return "\(Int((fraction * 100).rounded()))%"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Trends need data", systemImage: "chart.bar")
        } description: {
            Text("Add a few transactions and update your account balances. Plenty will start drawing the picture from there.")
        }
    }
}

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
