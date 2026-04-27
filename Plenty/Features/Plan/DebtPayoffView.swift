//
//  DebtPayoffView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/DebtPayoffView.swift
//
//  Pro-only full-screen debt payoff planner. Pushed from
//  DebtPayoffPlanCard via NavigationLink.
//
//  Sections, top to bottom:
//    1. Hero — total debt + months to debt-free at current strategy
//    2. Extra-payment slider — how much more per month above minimums
//    3. Strategy picker (PayoffStrategyView)
//    4. Path-to-debt-free chart (DebtChartView)
//    5. Per-debt breakdown with payoff order (DebtBreakdownView)
//
//  The slider snaps to $25 increments. Default extra is $0; the chart
//  and totals update live as the user drags.
//

import SwiftUI
import SwiftData

struct DebtPayoffView: View {

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    @State private var extraMonthly: Decimal = 0
    @State private var strategy: DebtEngine.Strategy = .avalanche

    private var debts: [Account] {
        DebtEngine.eligibleDebtAccounts(allAccounts)
    }

    private var totalDebt: Decimal {
        debts.reduce(Decimal.zero) { $0 + $1.balance }
    }

    private var avalanchePlan: DebtEngine.PayoffPlan? {
        DebtEngine.computePlan(debts: debts, extraMonthly: extraMonthly, strategy: .avalanche)
    }

    private var snowballPlan: DebtEngine.PayoffPlan? {
        DebtEngine.computePlan(debts: debts, extraMonthly: extraMonthly, strategy: .snowball)
    }

    private var selectedPlan: DebtEngine.PayoffPlan? {
        switch strategy {
        case .avalanche: return avalanchePlan
        case .snowball:  return snowballPlan
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if debts.isEmpty {
                    emptyState
                } else {
                    heroCard
                    extraSlider
                    PayoffStrategyView(
                        selection: $strategy,
                        avalanche: avalanchePlan,
                        snowball: snowballPlan
                    )
                    if let plan = selectedPlan {
                        DebtChartView(debts: debts, plan: plan)
                        DebtBreakdownView(debts: debts, strategy: strategy, plan: plan)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Debt payoff")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total debt")
                    .font(Typography.Support.label)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(totalDebt.asPlainCurrency())
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.terracotta)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            if let plan = selectedPlan {
                Divider()
                if plan.isPayable {
                    HStack(spacing: 32) {
                        miniStat(
                            label: "Debt-free in",
                            value: formattedDuration(plan.totalMonths)
                        )
                        miniStat(
                            label: "Total interest",
                            value: plan.totalInterest.asPlainCurrency()
                        )
                    }
                } else {
                    Text("With minimums and \(extraMonthly.asPlainCurrency())/mo extra, your debt grows. Increase the slider below to find a payable plan.")
                        .font(Typography.Support.footnote)
                        .foregroundStyle(Theme.terracotta)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Typography.Body.emphasis.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Extra Slider

    private var extraSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Extra per month")
                    .font(Typography.Body.emphasis)
                Spacer()
                Text(extraMonthly.asPlainCurrency())
                    .font(Typography.Currency.row.monospacedDigit())
                    .foregroundStyle(Theme.sage)
            }

            Slider(
                value: extraBinding,
                in: 0...1_000,
                step: 25
            )
            .tint(Theme.sage)

            Text("Above your minimum payments. Plenty stacks this onto the debt at the top of your strategy.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private var extraBinding: Binding<Double> {
        Binding(
            get: { NSDecimalNumber(decimal: extraMonthly).doubleValue },
            set: { extraMonthly = Decimal($0) }
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No debt to pay off", systemImage: "checkmark.circle")
        } description: {
            Text("Plenty needs at least one credit card or loan with a balance, an APR, and a minimum payment to plan a payoff.")
        }
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func formattedDuration(_ months: Int) -> String {
        if months <= 0 { return "Already paid" }
        if months < 12 { return "\(months) mo" }
        let years = months / 12
        let remainder = months % 12
        if remainder == 0 { return "\(years) yr" }
        return "\(years) yr \(remainder) mo"
    }
}

// MARK: - Local formatting

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
