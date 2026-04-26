//
//  DebtPayoffPlanCard.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/DebtPayoffPlanCard.swift
//
//  Side-by-side avalanche vs snowball debt payoff strategies. Both
//  computed by DebtEngine. Each card shows total months to debt
//  freedom and total interest paid.
//
//  v1 is informational only — the user picks a strategy mentally and
//  pays accordingly. A polish phase can wire active strategy selection
//  to bill order suggestions and the like.
//

import SwiftUI

struct DebtPayoffPlanCard: View {

    let debts: [Account]
    let monthlyExtraPayment: Decimal

    private var hasDebt: Bool { !debts.isEmpty }

    private var avalanchePlan: DebtEngine.PayoffPlan? {
        guard hasDebt else { return nil }
        return DebtEngine.computePlan(
            debts: debts,
            extraMonthly: monthlyExtraPayment,
            strategy: .avalanche
        )
    }

    private var snowballPlan: DebtEngine.PayoffPlan? {
        guard hasDebt else { return nil }
        return DebtEngine.computePlan(
            debts: debts,
            extraMonthly: monthlyExtraPayment,
            strategy: .snowball
        )
    }

    // MARK: - Body

    var body: some View {
        if !hasDebt {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                header

                HStack(spacing: 12) {
                    if let avalanche = avalanchePlan {
                        strategyCard(
                            title: "Avalanche",
                            subtitle: "Highest APR first",
                            plan: avalanche,
                            recommended: avalanche.totalInterest <= (snowballPlan?.totalInterest ?? .greatestFiniteMagnitude)
                        )
                    }

                    if let snowball = snowballPlan {
                        strategyCard(
                            title: "Snowball",
                            subtitle: "Smallest balance first",
                            plan: snowball,
                            recommended: false  // Avalanche always wins on interest; snowball wins on motivation
                        )
                    }
                }

                explainer
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Debt payoff")
                .font(Typography.Title.small)

            Text("Two ways to clear what you owe.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Strategy Card

    private func strategyCard(
        title: String,
        subtitle: String,
        plan: DebtEngine.PayoffPlan,
        recommended: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(Typography.Body.emphasis)
                if recommended {
                    Text("Saves more")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.sage)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Theme.sage.opacity(Theme.Opacity.soft))
                        )
                }
            }

            Text(subtitle)
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDuration(plan.totalMonths))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("\(plan.totalInterest.asPlainCurrency()) interest")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                .fill(Color.secondary.opacity(Theme.Opacity.hairline))
        )
    }

    // MARK: - Explainer

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Avalanche minimizes interest. Snowball builds momentum by clearing small balances first. Both work; pick the one you'll actually stick with.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
