//
//  DebtEngine.swift
//  Plenty
//
//  Target path: Plenty/Engine/DebtEngine.swift
//
//  Snowball and avalanche payoff strategy calculator. Port from Left.
//
//  Replaces the prior DebtEngine. Three additions:
//    • `Strategy` enum (avalanche / snowball)
//    • `PayoffPlan` struct (compact totalMonths + totalInterest summary)
//    • `computePlan(debts:extraMonthly:strategy:)` adapter that wraps
//      the existing `calculateAvalanche` / `calculateSnowball` and
//      returns a PayoffPlan for the cards and detail views.
//
//  No behavior change to the underlying simulator. The original
//  StrategyOutcome / StrategyComparison API is unchanged for callers
//  that need the full payoff steps (DebtPayoffView uses them).
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

    // MARK: - Strategy + Plan (used by cards)

    /// Selectable payoff strategy. The two cards on Plan tab and the
    /// detail view both use this.
    enum Strategy: String, Codable, CaseIterable, Identifiable, Sendable {
        case avalanche  // highest APR first
        case snowball   // smallest balance first

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .avalanche: return "Avalanche"
            case .snowball:  return "Snowball"
            }
        }

        var subtitle: String {
            switch self {
            case .avalanche: return "Highest APR first"
            case .snowball:  return "Smallest balance first"
            }
        }

        var explanation: String {
            switch self {
            case .avalanche:
                return "Pays down the debt with the highest interest rate first. Mathematically optimal — minimizes total interest paid."
            case .snowball:
                return "Pays down the smallest balance first. Builds momentum by clearing accounts quickly. Costs more interest but feels better."
            }
        }
    }

    /// Compact summary of a payoff strategy result. Cards and detail
    /// views format from this.
    struct PayoffPlan: Equatable, Sendable {
        let strategy: Strategy
        let totalMonths: Int
        let totalInterest: Decimal
        let isPayable: Bool

        /// Per-debt payoff order (for detail views).
        let steps: [PayoffStep]
    }

    /// Adapter for the cards. Wraps calculateAvalanche / calculateSnowball
    /// and packages the result as a PayoffPlan. Returns nil only when
    /// `debts` is empty; unpayable scenarios are signaled via
    /// `plan.isPayable == false` so the UI can show a "needs more
    /// monthly extra" message instead of nothing.
    static func computePlan(
        debts: [Account],
        extraMonthly: Decimal,
        strategy: Strategy
    ) -> PayoffPlan? {

        let eligible = eligibleDebtAccounts(debts)
        guard !eligible.isEmpty else { return nil }

        let outcome: StrategyOutcome
        switch strategy {
        case .avalanche:
            outcome = calculateAvalanche(accounts: eligible, extraMonthly: extraMonthly)
        case .snowball:
            outcome = calculateSnowball(accounts: eligible, extraMonthly: extraMonthly)
        }

        switch outcome {
        case .payoff(let months, let interest, let steps):
            return PayoffPlan(
                strategy: strategy,
                totalMonths: months,
                totalInterest: interest,
                isPayable: true,
                steps: steps
            )
        case .unpayable:
            return PayoffPlan(
                strategy: strategy,
                totalMonths: 0,
                totalInterest: 0,
                isPayable: false,
                steps: []
            )
        }
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

        if monthlyPayment <= monthlyInterest { return nil }

        var remaining = balance
        var totalInterest: Decimal = 0
        var months = 0
        let maxMonths = 1000

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

            for i in states.indices {
                let interest = states[i].balance * states[i].monthlyRate
                states[i].balance += interest
                totalInterest += interest
            }

            var extraPool = max(0, extraMonthly)

            for i in states.indices {
                let pay = min(states[i].minimum, states[i].balance)
                states[i].balance -= pay
                if pay < states[i].minimum {
                    extraPool += states[i].minimum - pay
                }
            }

            while extraPool > 0, let firstIdx = states.firstIndex(where: { $0.balance > 0 }) {
                let pay = min(extraPool, states[firstIdx].balance)
                states[firstIdx].balance -= pay
                extraPool -= pay
                if states[firstIdx].balance <= 0 { break }
            }

            var clearedIndices: [Int] = []
            for (i, state) in states.enumerated() where state.balance <= 0 {
                clearedIndices.append(i)

                let payoffDate = calendar.date(byAdding: .month, value: monthIndex - 1, to: startOfNextMonth) ?? .now
                steps.append(PayoffStep(
                    accountID: state.id,
                    accountName: state.name,
                    monthIndex: monthIndex,
                    payoffDate: payoffDate
                ))
            }

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
