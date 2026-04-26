//
//  AccountDerivations.swift
//  Plenty
//
//  Target path: Plenty/Engine/AccountDerivations.swift
//
//  Pure-function helpers over arrays of Account. No SwiftData, no side
//  effects, no state. Port from Left.
//

import Foundation

enum AccountDerivations {

    // MARK: - Filters

    static func activeAccounts(_ accounts: [Account]) -> [Account] {
        accounts.filter { $0.isActive && !$0.isClosed }
    }

    static func cashAccounts(_ accounts: [Account]) -> [Account] {
        activeAccounts(accounts).filter { $0.kind == .cash }
    }

    static func creditAccounts(_ accounts: [Account]) -> [Account] {
        activeAccounts(accounts).filter { $0.kind == .credit }
    }

    static func loanAccounts(_ accounts: [Account]) -> [Account] {
        activeAccounts(accounts).filter { $0.kind == .loan }
    }

    static func investmentAccounts(_ accounts: [Account]) -> [Account] {
        activeAccounts(accounts).filter { $0.kind == .investment }
    }

    /// Accounts the user can spend from directly (cash or credit).
    static func spendableAccounts(_ accounts: [Account]) -> [Account] {
        activeAccounts(accounts).filter { $0.kind.isSpendable }
    }

    static func hasCashAccount(_ accounts: [Account]) -> Bool {
        !cashAccounts(accounts).isEmpty
    }

    // MARK: - Totals

    static func cashAccountsTotal(_ accounts: [Account]) -> Decimal {
        cashAccounts(accounts).reduce(Decimal.zero) { $0 + $1.balance }
    }

    static func creditCardDebt(_ accounts: [Account]) -> Decimal {
        creditAccounts(accounts).reduce(Decimal.zero) { $0 + $1.balance }
    }

    static func loanDebt(_ accounts: [Account]) -> Decimal {
        loanAccounts(accounts).reduce(Decimal.zero) { $0 + $1.balance }
    }

    static func totalDebt(_ accounts: [Account]) -> Decimal {
        creditCardDebt(accounts) + loanDebt(accounts)
    }

    static func investmentTotal(_ accounts: [Account]) -> Decimal {
        investmentAccounts(accounts).reduce(Decimal.zero) { $0 + $1.balance }
    }

    /// Cash-on-hand: cash accounts total minus full credit card balance.
    /// This is net-worth-adjacent; the hero uses statement balance instead
    /// via BudgetEngine.
    static func cashOnHand(_ accounts: [Account]) -> Decimal {
        cashAccountsTotal(accounts) - creditCardDebt(accounts)
    }

    /// Total assets: cash + investments + other asset balances.
    static func totalAssets(_ accounts: [Account]) -> Decimal {
        activeAccounts(accounts)
            .filter { $0.isAsset }
            .reduce(Decimal.zero) { $0 + $1.balance }
    }

    /// Net worth: total assets minus total debt.
    static func netWorth(_ accounts: [Account]) -> Decimal {
        totalAssets(accounts) - totalDebt(accounts)
    }

    // MARK: - Default Selection

    /// Best-guess "default spending source" for quick-add flows. Prefers
    /// the most recently-updated spendable account.
    static func defaultSpendingSource(_ accounts: [Account]) -> Account? {
        spendableAccounts(accounts)
            .sorted { $0.balanceUpdatedAt > $1.balanceUpdatedAt }
            .first
    }
}
