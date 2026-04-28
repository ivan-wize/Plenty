//
//  HeroNumberView.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/HeroNumberView.swift
//
//  Phase 3 (v2): reads `snapshot.monthlyBudgetRemaining` instead of
//  `snapshot.spendable`. Color logic per PDS §4.1:
//
//      ≥ 0  →  sage
//      < 0  →  terracotta
//
//  Label adapts to sign:
//    • Positive → "You have"
//    • Zero     → "You're at zero this month"
//    • Negative → "You're over by"
//
//  The negative state shows the absolute value (no minus glyph in the
//  big number) since the label conveys direction. This avoids the
//  visual noise of a leading "−$" while still making the state
//  unambiguous.
//
//  Removed in v2:
//    • Zone-based color logic (sage/amber/terracotta four-state)
//    • Per-day context line ("That's about $45 a day.")
//    • Empty-state special copy ("Add a paycheck to see your number.")
//
//  The per-day context moves to The Read (when it has something
//  meaningful to say) and to the optional month-end projection line
//  in P7. The empty state is folded into the new label/messaging
//  ("You're at zero this month") which reads naturally at $0.
//

import SwiftUI

struct HeroNumberView: View {

    let snapshot: PlentySnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var didEnterNegative = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            label

            Text(formattedAmount)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: amountAsDouble))
                .animation(reduceMotion ? nil : .snappy, value: snapshot.monthlyBudgetRemaining)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onChange(of: snapshot.monthlyBudgetIsNegative) { wasNegative, isNegative in
            if isNegative && !wasNegative {
                didEnterNegative.toggle()
            }
        }
        .sensoryFeedback(.warning, trigger: didEnterNegative)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Label

    @ViewBuilder
    private var label: some View {
        Text(labelText)
            .font(Typography.Support.caption)
            .foregroundStyle(.secondary)
            .textCase(snapshot.monthlyBudgetRemaining == 0 ? .uppercase : nil)
            .tracking(snapshot.monthlyBudgetRemaining == 0 ? 0.6 : 0)
    }

    private var labelText: String {
        if snapshot.monthlyBudgetRemaining > 0 {
            return "You have"
        } else if snapshot.monthlyBudgetRemaining < 0 {
            return "You're over by"
        } else {
            return "You're at zero this month"
        }
    }

    // MARK: - Number

    private var formattedAmount: String {
        let value = abs(snapshot.monthlyBudgetRemaining)
        return value.asPlainCurrency()
    }

    private var numberColor: Color {
        snapshot.monthlyBudgetIsNegative ? Theme.terracotta : Theme.sage
    }

    private var amountAsDouble: Double {
        NSDecimalNumber(decimal: snapshot.monthlyBudgetRemaining).doubleValue
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let amount = abs(snapshot.monthlyBudgetRemaining).asPlainCurrency()
        if snapshot.monthlyBudgetRemaining > 0 {
            return "You have \(amount) of budget remaining this month."
        } else if snapshot.monthlyBudgetRemaining < 0 {
            return "You're over your budget by \(amount) this month."
        } else {
            return "You're at zero budget remaining this month."
        }
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

// MARK: - Previews

#Preview("Positive — $1,840") {
    HeroNumberView(snapshot: .v2Preview(monthlyBudgetRemaining: 1840))
        .background(Theme.background)
}

#Preview("Zero") {
    HeroNumberView(snapshot: .v2Preview(monthlyBudgetRemaining: 0))
        .background(Theme.background)
}

#Preview("Negative — −$540") {
    HeroNumberView(snapshot: .v2Preview(monthlyBudgetRemaining: -540))
        .background(Theme.background)
}

// MARK: - Preview Snapshots

private extension PlentySnapshot {
    static func v2Preview(monthlyBudgetRemaining: Decimal) -> PlentySnapshot {
        PlentySnapshot(
            spendable: monthlyBudgetRemaining,
            cashOnHand: 4200,
            cashAccountsTotal: 4200,
            creditCardDebt: 0,
            statementDueBeforeNextIncome: 0,
            billsRemaining: 0,
            billsTotal: 1700,
            billsPaid: 1700,
            expensesThisMonth: 460,
            confirmedIncome: 4000,
            expectedIncome: 0,
            totalIncome: 4000,
            nextIncomeDate: nil,
            plannedSavingsThisMonth: 0,
            actualSavingsThisMonth: 0,
            plannedSavingsRemaining: 0,
            smoothedDailyBurn: 38,
            sustainableDailyBurn: 92,
            billsPaidCount: 4,
            billsTotalCount: 4,
            incomeConfirmedCount: 1,
            incomeTotalCount: 1,
            expensesByCategory: [],
            monthlyBudgetRemaining: monthlyBudgetRemaining
        )
    }
}
