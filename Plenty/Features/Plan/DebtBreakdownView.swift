//
//  DebtBreakdownView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/DebtBreakdownView.swift
//
//  Per-debt rows used inside DebtPayoffView. Shows each eligible debt
//  with its current balance, APR, minimum, and (optionally) the
//  payoff order under the selected strategy.
//
//  Order in the list reflects the strategy:
//    • Avalanche: highest APR first
//    • Snowball:  smallest balance first
//

import SwiftUI

struct DebtBreakdownView: View {

    let debts: [Account]
    let strategy: DebtEngine.Strategy
    /// Pass the plan for this strategy so we can show the payoff month
    /// for each debt. Pass nil to omit the timeline column.
    let plan: DebtEngine.PayoffPlan?

    private var ordered: [Account] {
        switch strategy {
        case .avalanche:
            return debts.sorted { ($0.interestRate ?? 0) > ($1.interestRate ?? 0) }
        case .snowball:
            return debts.sorted { $0.balance < $1.balance }
        }
    }

    private var stepsByAccount: [UUID: DebtEngine.PayoffStep] {
        guard let plan else { return [:] }
        return Dictionary(uniqueKeysWithValues: plan.steps.map { ($0.accountID, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your debts")
                .font(Typography.Title.small)

            VStack(spacing: 8) {
                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, debt in
                    debtRow(index: index, debt: debt)
                }
            }
        }
    }

    // MARK: - Row

    private func debtRow(index: Int, debt: Account) -> some View {
        let step = stepsByAccount[debt.id]

        return HStack(alignment: .top, spacing: 12) {
            // Order badge.
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.sage)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(debt.name)
                        .font(Typography.Body.emphasis)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(debt.balance.asPlainCurrency())
                        .font(Typography.Currency.row.monospacedDigit())
                        .foregroundStyle(Theme.terracotta)
                }

                HStack(spacing: 12) {
                    metric(label: "APR", value: aprString(debt))
                    metric(label: "Min",  value: minString(debt))

                    if let step {
                        metric(label: "Cleared", value: payoffMonthLabel(step.payoffDate))
                    }

                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inline, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private func metric(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(Typography.Support.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(Typography.Support.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func aprString(_ debt: Account) -> String {
        guard let rate = debt.interestRate else { return "—" }
        return String(format: "%.1f%%", NSDecimalNumber(decimal: rate).doubleValue)
    }

    private func minString(_ debt: Account) -> String {
        guard let min = debt.minimumPayment, min > 0 else { return "—" }
        return min.asPlainCurrency()
    }

    private func payoffMonthLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
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
