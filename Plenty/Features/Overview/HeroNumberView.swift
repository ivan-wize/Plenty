//
//  HeroNumberView.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/HeroNumberView.swift
//
//  Phase 1.2 (post-launch v1): three-state color rule. Sage is now
//  reserved for *positive* monthlyBudgetRemaining. Zero-but-active
//  renders in `.primary` (charcoal in light, off-white in dark) so
//  sage carries real meaning when it appears. Negative stays
//  terracotta.
//
//      > 0  →  Theme.sage          ("you have margin")
//      < 0  →  Theme.terracotta    ("you're over")
//      = 0  →  .primary            (calm, no editorialization)
//
//  Why this matters: in the previous two-state rule, $0 rendered in
//  sage along with $4,000. Sage stopped being a signal of margin and
//  became a default. This change costs three lines of code and
//  restores the meaning of the brand color.
//
//  ----- Earlier history -----
//
//  Phase 3 (v2): reads `snapshot.monthlyBudgetRemaining` instead of
//  `snapshot.spendable`.
//
//  Label adapts to sign:
//    • Positive → "You have"
//    • Zero     → "You're at zero this month"
//    • Negative → "You're over by"
//
//  The negative state shows the absolute value (no minus glyph in
//  the big number) since the label conveys direction. This avoids
//  the visual noise of a leading "−$" while still making the state
//  unambiguous.
//
//  Note on the empty state: HeroNumberView is no longer responsible
//  for "no data yet" copy. OverviewTab branches at the call site to
//  OverviewEmptyHero when `BudgetEngine.hasAnySetupData(...)` is
//  false, so HeroNumberView only ever renders when there's a
//  meaningful number to show.
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

    /// Three-state color rule (Phase 1.2). Sage is reserved for
    /// *positive* margin so its appearance carries meaning. Zero
    /// renders in `.primary` rather than sage so the brand color
    /// doesn't become a default.
    private var numberColor: Color {
        if snapshot.monthlyBudgetRemaining > 0 { return Theme.sage }
        if snapshot.monthlyBudgetRemaining < 0 { return Theme.terracotta }
        return .primary
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

#Preview("Positive — $1,840 (sage)") {
    HeroNumberView(snapshot: .v2Preview(monthlyBudgetRemaining: 1840))
        .background(Theme.background)
}

#Preview("Zero — primary, not sage") {
    HeroNumberView(snapshot: .v2Preview(monthlyBudgetRemaining: 0))
        .background(Theme.background)
}

#Preview("Negative — −$540 (terracotta)") {
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
