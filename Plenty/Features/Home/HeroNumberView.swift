//
//  HeroNumberView.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/HeroNumberView.swift
//
//  The big number on Home. Plenty's hero is restrained: big bold
//  tabular numerals, plenty of breathing room, color that shifts
//  subtly with zone. No ring decoration, no progress arc — the
//  typography is the design.
//
//  Color logic per PRD §6:
//    .safe    → primary (charcoal in light, off-white in dark)
//    .warning → amber, but only the number, never the whole region
//    .over    → terracotta
//    .empty   → secondary (muted)
//
//  Below the number sits a one-line context label that adapts to zone.
//  The Read appears separately beneath via TheReadView.
//

import SwiftUI

struct HeroNumberView: View {

    let snapshot: PlentySnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var didEnterWarning = false
    @State private var didEnterOver = false

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
                .contentTransition(.numericText(value: spendableAsDouble))
                .animation(reduceMotion ? nil : .snappy, value: snapshot.spendable)

            contextLine
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onChange(of: snapshot.zone) { oldZone, newZone in
            if newZone == .warning && oldZone != .warning {
                didEnterWarning.toggle()
            }
            if newZone == .over && oldZone != .over {
                didEnterOver.toggle()
            }
        }
        .sensoryFeedback(.warning, trigger: didEnterWarning)
        .sensoryFeedback(.error, trigger: didEnterOver)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Label

    @ViewBuilder
    private var label: some View {
        if snapshot.zone == .empty {
            Text("Spendable")
                .font(Typography.Support.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)
        } else {
            Text("You have")
                .font(Typography.Support.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Context Line

    @ViewBuilder
    private var contextLine: some View {
        switch snapshot.zone {
        case .empty:
            Text("Add a paycheck to see your number.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.tertiary)

        case .safe:
            if let perDay = snapshot.sustainableDailyBurn, perDay > 0 {
                Text("That's about \(perDay.asPlainCurrency()) a day.")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Spendable through this month.")
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }

        case .warning:
            Text("Spending pace deserves a glance.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)

        case .over:
            Text("You're past your margin this month.")
                .font(Typography.Support.footnote)
                .foregroundStyle(Theme.terracotta)
        }
    }

    // MARK: - Computed

    private var formattedAmount: String {
        if snapshot.zone == .empty {
            return "—"
        }

        let value = snapshot.spendable
        let absValue = value < 0 ? -value : value
        let formatted = absValue.asPlainCurrency()
        return value < 0 ? "−\(formatted)" : formatted
    }

    private var spendableAsDouble: Double {
        NSDecimalNumber(decimal: snapshot.spendable).doubleValue
    }

    private var numberColor: Color {
        switch snapshot.zone {
        case .empty:   return .secondary.opacity(0.5)
        case .safe:    return .primary
        case .warning: return Theme.amber
        case .over:    return Theme.terracotta
        }
    }

    private var accessibilityDescription: String {
        switch snapshot.zone {
        case .empty:
            return "No spendable amount yet. Add a paycheck to see your number."
        case .safe, .warning:
            let amount = snapshot.spendable.asPlainCurrency()
            return "You have \(amount) spendable this month."
        case .over:
            let amount = (snapshot.spendable < 0 ? -snapshot.spendable : snapshot.spendable).asPlainCurrency()
            return "You are over your margin by \(amount) this month."
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

#Preview("Safe") {
    HeroNumberView(snapshot: .preview(.safe))
        .background(Theme.background)
}

#Preview("Warning") {
    HeroNumberView(snapshot: .preview(.warning))
        .background(Theme.background)
}

#Preview("Over") {
    HeroNumberView(snapshot: .preview(.over))
        .background(Theme.background)
}

#Preview("Empty") {
    HeroNumberView(snapshot: .preview(.empty))
        .background(Theme.background)
}

// MARK: - Preview Snapshots

private extension PlentySnapshot {
    static func preview(_ zone: PlentySnapshot.Zone) -> PlentySnapshot {
        switch zone {
        case .safe:
            return PlentySnapshot(
                spendable: 1840, cashOnHand: 4200, cashAccountsTotal: 4200,
                creditCardDebt: 0, statementDueBeforeNextIncome: 0,
                billsRemaining: 850, billsTotal: 1700, billsPaid: 850,
                expensesThisMonth: 620,
                confirmedIncome: 3200, expectedIncome: 0, totalIncome: 3200,
                nextIncomeDate: nil,
                plannedSavingsThisMonth: 500, actualSavingsThisMonth: 250,
                plannedSavingsRemaining: 250,
                smoothedDailyBurn: 38, sustainableDailyBurn: 92,
                billsPaidCount: 2, billsTotalCount: 4,
                incomeConfirmedCount: 1, incomeTotalCount: 1,
                expensesByCategory: []
            )
        case .warning:
            var s = PlentySnapshot.preview(.safe)
            s = PlentySnapshot(
                spendable: 320, cashOnHand: s.cashOnHand, cashAccountsTotal: s.cashAccountsTotal,
                creditCardDebt: s.creditCardDebt, statementDueBeforeNextIncome: s.statementDueBeforeNextIncome,
                billsRemaining: s.billsRemaining, billsTotal: s.billsTotal, billsPaid: s.billsPaid,
                expensesThisMonth: s.expensesThisMonth,
                confirmedIncome: s.confirmedIncome, expectedIncome: s.expectedIncome, totalIncome: s.totalIncome,
                nextIncomeDate: s.nextIncomeDate,
                plannedSavingsThisMonth: s.plannedSavingsThisMonth, actualSavingsThisMonth: s.actualSavingsThisMonth,
                plannedSavingsRemaining: s.plannedSavingsRemaining,
                smoothedDailyBurn: 110, sustainableDailyBurn: 25,
                billsPaidCount: s.billsPaidCount, billsTotalCount: s.billsTotalCount,
                incomeConfirmedCount: s.incomeConfirmedCount, incomeTotalCount: s.incomeTotalCount,
                expensesByCategory: s.expensesByCategory
            )
            return s
        case .over:
            return PlentySnapshot(
                spendable: -240, cashOnHand: 200, cashAccountsTotal: 200,
                creditCardDebt: 0, statementDueBeforeNextIncome: 0,
                billsRemaining: 440, billsTotal: 440, billsPaid: 0,
                expensesThisMonth: 1800,
                confirmedIncome: 2200, expectedIncome: 0, totalIncome: 2200,
                nextIncomeDate: nil,
                plannedSavingsThisMonth: 0, actualSavingsThisMonth: 0,
                plannedSavingsRemaining: 0,
                smoothedDailyBurn: 75, sustainableDailyBurn: nil,
                billsPaidCount: 0, billsTotalCount: 1,
                incomeConfirmedCount: 1, incomeTotalCount: 1,
                expensesByCategory: []
            )
        case .empty:
            return .empty
        }
    }
}
