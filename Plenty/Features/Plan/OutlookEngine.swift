//
//  OutlookEngine.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/OutlookEngine.swift
//
//  12-month projection of spendable cash. Linear arithmetic per month:
//
//    ending_cash[m] = starting_cash + expected_income[m] - recurring_bills[m]
//
//  Where:
//    starting_cash = current cash on hand (real, from Account totals)
//    expected_income[m] = sum of materialized + projected income for month m
//      (uses IncomeSource templates to project forward)
//    recurring_bills[m] = sum of recurring bills due in month m
//      (uses RecurringRule on existing .bill transactions to project)
//
//  This is the simple version. Production-quality would also account for:
//    • Variable income (last-12-month median for non-templated sources)
//    • Statement balance cycles (which Phase 0 Decision 3.2 does for Home)
//    • Savings goal contributions
//    • One-time expenses (vacation, taxes)
//
//  None of those are in v1. Documenting the simplification clearly so
//  the user understands the projection's limits.
//
//  Returns 12 OutlookMonth records starting from the current month.
//

import Foundation

enum OutlookEngine {

    // MARK: - Output

    struct Month: Identifiable, Hashable, Sendable {
        let monthIndex: Int      // 1...12
        let year: Int
        let label: String        // "Apr"
        let projectedIncome: Decimal
        let projectedBills: Decimal
        let projectedNet: Decimal       // income - bills
        let projectedEndingCash: Decimal // running balance

        var id: String { "\(year)-\(monthIndex)" }
    }

    // MARK: - Public

    /// Project 12 months forward starting from the given month/year.
    /// `startingCash` is the current cash-on-hand snapshot (typically
    /// PlentySnapshot.cashOnHand).
    static func project(
        startingCash: Decimal,
        from startMonth: Int,
        year startYear: Int,
        incomeSources: [IncomeSource],
        recurringBills: [Transaction],
        calendar: Calendar = .current
    ) -> [Month] {
        var results: [Month] = []
        var runningCash = startingCash

        for offset in 0..<12 {
            let (m, y) = monthYear(from: startMonth, year: startYear, offset: offset)

            let income = projectedIncomeForMonth(
                month: m,
                year: y,
                sources: incomeSources,
                calendar: calendar
            )

            let bills = projectedBillsForMonth(
                month: m,
                year: y,
                recurringBills: recurringBills,
                calendar: calendar
            )

            let net = income - bills
            runningCash += net

            results.append(Month(
                monthIndex: m,
                year: y,
                label: monthLabel(month: m, calendar: calendar),
                projectedIncome: income,
                projectedBills: bills,
                projectedNet: net,
                projectedEndingCash: runningCash
            ))
        }

        return results
    }

    // MARK: - Income Projection

    private static func projectedIncomeForMonth(
        month: Int,
        year: Int,
        sources: [IncomeSource],
        calendar: Calendar
    ) -> Decimal {
        sources
            .filter { $0.isActive }
            .reduce(Decimal.zero) { partial, source in
                partial + source.projectedAmountForMonth(month: month, year: year, calendar: calendar)
            }
    }

    // MARK: - Bills Projection

    /// Walks each existing .bill transaction (which carries a
    /// RecurringRule) and asks the rule whether it would generate an
    /// occurrence in the given month/year. Sums those amounts.
    private static func projectedBillsForMonth(
        month: Int,
        year: Int,
        recurringBills: [Transaction],
        calendar: Calendar
    ) -> Decimal {
        recurringBills
            .compactMap { tx -> Decimal? in
                guard tx.kind == .bill, let rule = tx.recurringRule else {
                    return nil
                }
                return rule.occursIn(month: month, year: year, calendar: calendar) ? tx.amount : nil
            }
            .reduce(Decimal.zero, +)
    }

    // MARK: - Helpers

    private static func monthYear(from startMonth: Int, year startYear: Int, offset: Int) -> (Int, Int) {
        let zeroBased = startMonth - 1 + offset
        let year = startYear + zeroBased / 12
        let month = (zeroBased % 12) + 1
        return (month, year)
    }

    private static func monthLabel(month: Int, calendar: Calendar) -> String {
        let symbols = calendar.shortMonthSymbols
        return symbols.indices.contains(month - 1) ? symbols[month - 1] : "\(month)"
    }
}

// MARK: - IncomeSource Projection Helper

extension IncomeSource {

    /// How much this source is expected to contribute in the given
    /// month, based on its frequency.
    func projectedAmountForMonth(month: Int, year: Int, calendar: Calendar) -> Decimal {
        guard isActive else { return 0 }

        switch frequency {
        case .monthly:
            return expectedAmount

        case .semimonthly:
            return expectedAmount * 2

        case .biweekly:
            // Biweekly = 26 paychecks/year. Most months have 2;
            // two months a year have 3. Approximate with 2.17/month
            // for projection purposes (close enough for planning, not
            // exact for any specific month).
            return expectedAmount * Decimal(2.17)

        case .weekly:
            // Weekly = 52 paychecks/year. Average 4.33/month.
            return expectedAmount * Decimal(4.33)
        }
    }
}

// MARK: - RecurringRule Occurrence Check

extension RecurringRule {

    /// Whether this rule would generate an occurrence in the given
    /// month/year. Phase 6 only handles the monthly case; weekly/annual
    /// would need separate handling here.
    func occursIn(month: Int, year: Int, calendar: Calendar = .current) -> Bool {
        switch frequency {
        case .monthly:
            // Monthly rules occur every month after their start.
            var startComponents = DateComponents()
            startComponents.year = year
            startComponents.month = month
            startComponents.day = dayOfMonth ?? 1
            guard let target = calendar.date(from: startComponents) else { return false }
            return target >= startDate
        case .weekly, .annual:
            // Phase 6 simplification: only monthly bills project.
            // Weekly bills (rare) and annual bills (HOA, taxes) won't
            // appear in Outlook in v1.
            return false
        }
    }
}
