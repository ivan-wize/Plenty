//
//  BudgetEngine+Savings.swift
//  Plenty
//
//  Target path: Plenty/Engine/BudgetEngine+Savings.swift
//
//  Savings-specific helpers on BudgetEngine. Kept separate so the core
//  engine stays tightly focused on the hero number.
//

import Foundation

extension BudgetEngine {

    /// Round a Decimal to whole dollars. Used for suggested contribution
    /// amounts where cents would feel fussy.
    static func roundToWholeDollars(_ value: Decimal) -> Decimal {
        var v = value
        var out = Decimal.zero
        NSDecimalRound(&out, &v, 0, .bankers)
        return out
    }
}
