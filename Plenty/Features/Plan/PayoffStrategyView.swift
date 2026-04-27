//
//  PayoffStrategyView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/PayoffStrategyView.swift
//
//  The avalanche-vs-snowball selector inside DebtPayoffView. Two cards
//  side by side, tap to select. The selected card gets a sage outline;
//  both cards always show their own totals so the user can compare.
//
//  Recommended pill is shown on the strategy that minimizes total
//  interest (mathematically: avalanche, unless rates are equal in which
//  case avalanche and snowball collapse and either is fine).
//

import SwiftUI

struct PayoffStrategyView: View {

    @Binding var selection: DebtEngine.Strategy
    let avalanche: DebtEngine.PayoffPlan?
    let snowball:  DebtEngine.PayoffPlan?

    private var avalancheRecommended: Bool {
        guard let avalanche, let snowball else { return false }
        return avalanche.totalInterest <= snowball.totalInterest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strategy")
                .font(Typography.Title.small)

            HStack(spacing: 12) {
                if let avalanche {
                    strategyCard(plan: avalanche, isRecommended: avalancheRecommended)
                }
                if let snowball {
                    strategyCard(plan: snowball, isRecommended: !avalancheRecommended && avalanche?.totalInterest == snowball.totalInterest ? false : false)
                }
            }

            explainerForSelection
        }
    }

    // MARK: - Card

    private func strategyCard(plan: DebtEngine.PayoffPlan, isRecommended: Bool) -> some View {
        let isSelected = selection == plan.strategy

        return Button {
            selection = plan.strategy
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(plan.strategy.displayName)
                        .font(Typography.Body.emphasis)
                    if isRecommended {
                        Text("Saves more")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.sage)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.sage.opacity(Theme.Opacity.soft)))
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.sage)
                            .font(.body)
                    }
                }

                Text(plan.strategy.subtitle)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)

                if plan.isPayable {
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
                } else {
                    Text("Needs more monthly")
                        .font(Typography.Support.footnote)
                        .foregroundStyle(Theme.terracotta)
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                    .fill(isSelected ? Theme.sage.opacity(Theme.Opacity.soft) : Color.secondary.opacity(Theme.Opacity.hairline))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                            .stroke(isSelected ? Theme.sage : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Explainer

    private var explainerForSelection: some View {
        Text(selection.explanation)
            .font(Typography.Support.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
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
