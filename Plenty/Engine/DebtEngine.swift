//
//  DebtEngine.swift
//  Plenty
//
//  Target path: Plenty/Engine/DebtEngine.swift
//
//  Snowball and avalanche payoff strategy calculator. Port from Left.
//
//  Model of reality:
//    • User commits to a fixed monthly outflow: sum(minimums) + extra
//    • Each month, every debt accrues interest, then receives its minimum
//    • Extra (including freed minimums from cleared debts) stacks onto
//      the highest-priority remaining debt, cascading as debts clear
//    • Priority is determined by the ordering closure (snowball =
//      smallest balance first; avalanche = highest rate first)
//

import Foundation

enum DebtEngine {

    // MARK: - Value Types

    struct PayoffResult: Equatable, Sendable {
        let months: Int
        let totalInterest: Decimal
    }

    struct PayoffStep: Equatable, Sendable, Identifiable {
        var id: String { "\(accountID):\(monthIndex)" }
        let accountID: UUID
        let accountName: String
        let monthIndex: Int
        let payoffDate: Date
    }

    enum StrategyOutcome: Equatable, Sendable {
        case payoff(months: Int, totalInterest: Decimal, steps: [PayoffStep])
        case unpayable(minimumExtraNeeded: Decimal)

        var months: Int? {
            if case .payoff(let m, _, _) = self { return m }
            return nil
        }

        var totalInterest: Decimal? {
            if case .payoff(_, let i, _) = self { return i }
            return nil
        }

        var steps: [PayoffStep] {
            if case .payoff(_, _, let s) = self { return s }
            return []
        }

        var isPayable: Bool {
            if case .payoff = self { return true }
            return false
        }
    }

    struct StrategyComparison: Equatable, Sendable {
        let snowball: StrategyOutcome
        let avalanche: StrategyOutcome
        let minimumOnly: StrategyOutcome
    }

    // MARK: - Filters

    static func eligibleDebtAccounts(_ accounts: [Account]) -> [Account] {
        accounts.filter { account in
            guard account.isActive, !account.isClosed else { return false }
            guard account.kind == .credit || account.kind == .loan else { return false }
            guard account.balance > 0 else { return false }
            guard let minimum = account.minimumPayment, minimum > 0 else { return false }
            guard account.interestRate != nil else { return false }
            return true
        }
    }

    // MARK: - Single Debt

    static func calculatePayoffTimeline(
        balance: Decimal,
        rate: Decimal,
        monthlyPayment: Decimal
    ) -> PayoffResult? {
        guard balance > 0, monthlyPayment > 0 else { return nil }

        let monthlyRate = rate / 100 / 12
        let monthlyInterest = balance * monthlyRate

        // Monthly payment must cover at least the monthly interest.
        if monthlyPayment <= monthlyInterest { return nil }

        var remaining = balance
        var totalInterest: Decimal = 0
        var months = 0
        let maxMonths = 1000  // safety cap

        while remaining > 0 && months < maxMonths {
            let interest = remaining * monthlyRate
            totalInterest += interest
            remaining = remaining + interest - monthlyPayment
            months += 1
            if remaining < 0 { remaining = 0 }
        }

        return PayoffResult(months: months, totalInterest: roundToCents(totalInterest))
    }

    // MARK: - Public Strategies

    static func compareStrategies(accounts: [Account], extraMonthly: Decimal = 0) -> StrategyComparison? {
        let eligible = eligibleDebtAccounts(accounts)
        guard !eligible.isEmpty else { return nil }

        return StrategyComparison(
            snowball: calculateSnowball(accounts: eligible, extraMonthly: extraMonthly),
            avalanche: calculateAvalanche(accounts: eligible, extraMonthly: extraMonthly),
            minimumOnly: calculateMinimumOnly(accounts: eligible)
        )
    }

    static func calculateSnowball(accounts: [Account], extraMonthly: Decimal) -> StrategyOutcome {
        calculateCascadingStrategy(accounts: accounts, extraMonthly: extraMonthly) {
            $0.balance < $1.balance
        }
    }

    static func calculateAvalanche(accounts: [Account], extraMonthly: Decimal) -> StrategyOutcome {
        calculateCascadingStrategy(accounts: accounts, extraMonthly: extraMonthly) {
            ($0.interestRate ?? 0) > ($1.interestRate ?? 0)
        }
    }

    static func calculateMinimumOnly(accounts: [Account]) -> StrategyOutcome {
        var longestMonths = 0
        var summedInterest: Decimal = 0
        var shortfall: Decimal = 0
        var hasUnpayableDebt = false

        for account in accounts where account.balance > 0 {
            let rate = account.interestRate ?? 0
            let minimum = account.minimumPayment ?? 0

            if let result = calculatePayoffTimeline(
                balance: account.balance,
                rate: rate,
                monthlyPayment: minimum
            ) {
                longestMonths = max(longestMonths, result.months)
                summedInterest += result.totalInterest
            } else {
                hasUnpayableDebt = true
                let monthlyInterest = account.balance * rate / 100 / 12
                shortfall += max(Decimal(0), monthlyInterest - minimum)
            }
        }

        if hasUnpayableDebt {
            return .unpayable(minimumExtraNeeded: roundToCents(shortfall + oneCent))
        }

        return .payoff(
            months: longestMonths,
            totalInterest: roundToCents(summedInterest),
            steps: []
        )
    }

    // MARK: - Cascading Simulator

    private struct DebtState {
        let name: String
        let id: UUID
        var balance: Decimal
        let monthlyRate: Decimal
        let minimum: Decimal
    }

    private static func calculateCascadingStrategy(
        accounts: [Account],
        extraMonthly: Decimal,
        ordering: (Account, Account) -> Bool
    ) -> StrategyOutcome {

        guard !accounts.isEmpty else {
            return .payoff(months: 0, totalInterest: 0, steps: [])
        }

        // Check feasibility: sum of minimums must cover total monthly interest.
        var totalMonthlyInterest: Decimal = 0
        var totalMinimums: Decimal = 0
        for account in accounts where account.balance > 0 {
            let rate = (account.interestRate ?? 0) / 100 / 12
            totalMonthlyInterest += account.balance * rate
            totalMinimums += account.minimumPayment ?? 0
        }

        let totalBudget = totalMinimums + max(0, extraMonthly)
        if totalBudget <= totalMonthlyInterest {
            let needed = max(0, totalMonthlyInterest - totalMinimums) + oneCent
            return .unpayable(minimumExtraNeeded: roundToCents(needed))
        }

        // Build the simulation state, ordered by the strategy.
        var states: [DebtState] = accounts
            .filter { $0.balance > 0 }
            .sorted(by: ordering)
            .map { account in
                DebtState(
                    name: account.name,
                    id: account.id,
                    balance: account.balance,
                    monthlyRate: (account.interestRate ?? 0) / 100 / 12,
                    minimum: account.minimumPayment ?? 0
                )
            }

        var totalInterest: Decimal = 0
        var monthIndex = 0
        var steps: [PayoffStep] = []
        let calendar = Calendar.current
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: .now) ?? .now

        let maxMonths = 1000
        while !states.isEmpty && monthIndex < maxMonths {
            monthIndex += 1

            // 1. Accrue interest on every debt.
            for i in states.indices {
                let interest = states[i].balance * states[i].monthlyRate
                states[i].balance += interest
                totalInterest += interest
            }

            // 2. Pay minimums on every debt.
            var extraPool = max(0, extraMonthly)
            var minimumsFreed: Decimal = 0

            for i in states.indices {
                let pay = min(states[i].minimum, states[i].balance)
                states[i].balance -= pay
                // Freed minimum: if this debt is smaller than its minimum,
                // the excess adds to the extra pool.
                if pay < states[i].minimum {
                    extraPool += states[i].minimum - pay
                }
            }

            // 3. Apply extra pool to the highest-priority remaining debt.
            while extraPool > 0, let firstIdx = states.firstIndex(where: { $0.balance > 0 }) {
                let pay = min(extraPool, states[firstIdx].balance)
                states[firstIdx].balance -= pay
                extraPool -= pay
                if states[firstIdx].balance <= 0 { break }
            }

            // 4. Collect cleared debts. Their minimums are freed for future months.
            var clearedIndices: [Int] = []
            for (i, state) in states.enumerated() where state.balance <= 0 {
                clearedIndices.append(i)
                minimumsFreed += state.minimum

                let payoffDate = calendar.date(byAdding: .month, value: monthIndex - 1, to: startOfNextMonth) ?? .now
                steps.append(PayoffStep(
                    accountID: state.id,
                    accountName: state.name,
                    monthIndex: monthIndex,
                    payoffDate: payoffDate
                ))
            }

            // Remove cleared debts.
            for i in clearedIndices.reversed() {
                states.remove(at: i)
            }
        }

        if monthIndex >= maxMonths {
            return .unpayable(minimumExtraNeeded: roundToCents(oneCent))
        }

        return .payoff(
            months: monthIndex,
            totalInterest: roundToCents(totalInterest),
            steps: steps
        )
    }

    // MARK: - Helpers

    private static let oneCent: Decimal = Decimal(string: "0.01") ?? 0

    private static func roundToCents(_ value: Decimal) -> Decimal {
        var v = value
        var out = Decimal.zero
        NSDecimalRound(&out, &v, 2, .bankers)
        return out
    }
}
