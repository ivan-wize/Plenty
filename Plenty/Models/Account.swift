//
//  Account.swift
//  Plenty
//
//  Target path: Plenty/Models/Account.swift
//
//  A unified financial account. Handles cash, credit, investment, and
//  loan accounts through a category discriminator.
//
//  Port from Left with two additions:
//    • `statementBalance: Decimal?` supports the refined hero math from
//      Phase 0 Decision 3.2. When set on a credit card, the hero
//      subtracts this amount (the upcoming statement) rather than the
//      full outstanding balance.
//    • `isShared: Bool = false` is the V1.1 sharing hook. Dormant in V1.0.
//
//  CloudKit requirements respected:
//    • Every stored property has a default value at declaration.
//    • Relationships are optional arrays.
//    • No @Attribute(.unique).
//

import Foundation
import SwiftData

@Model
final class Account {

    // MARK: - Identity

    var id: UUID = UUID()

    /// User-chosen name: "Chase Checking," "Apple Card," "Fidelity 401k."
    var name: String = ""

    /// Category discriminator. Stored raw for CloudKit.
    var categoryRaw: String = AccountCategory.debit.rawValue

    // MARK: - Balance

    /// Current balance as the user last recorded it.
    ///
    /// Convention: ALWAYS stored as positive magnitude. `kind.isAsset`
    /// determines the sign in aggregations. A credit card with $2,000
    /// owed has balance = 2000, not -2000.
    var balance: Decimal = 0

    /// When the balance was last updated by the user.
    var balanceUpdatedAt: Date = Date()

    // MARK: - Credit/Loan Fields (optional)

    /// APR as a percentage (19.99 for 19.99%). Nil for cash/investment.
    var interestRate: Decimal?

    /// Monthly minimum payment. Nil if unknown or N/A.
    var minimumPayment: Decimal?

    /// Credit limit for cards, original principal for loans. Nil if unknown.
    var creditLimitOrOriginalBalance: Decimal?

    /// Statement cycle day (1-28) for credit cards, if known.
    var statementDay: Int?

    /// Statement balance due on the upcoming statement date. New in Plenty.
    /// When set, the hero number subtracts this amount if the statement
    /// falls before the next income event. When nil, nothing is subtracted
    /// for this card (the user hasn't told us what's due). Per Phase 0
    /// Decision 3.2.
    ///
    /// Only meaningful for credit card accounts. Ignored for others.
    var statementBalance: Decimal?

    // MARK: - Organization

    var sortOrder: Int = 0

    /// Whether this account appears in active lists.
    var isActive: Bool = true

    /// Whether this account is closed/paid off.
    var isClosed: Bool = false

    /// When the account was marked closed.
    var closedAt: Date?

    var note: String?

    // MARK: - Sharing (V1.1 hook)

    /// Reserved for V1.1 household sharing. Dormant in V1.0.
    var isShared: Bool = false

    // MARK: - Relationships

    /// Historical balance snapshots. Cascade delete: close an account,
    /// its history goes too.
    @Relationship(deleteRule: .cascade, inverse: \AccountBalance.account)
    var balanceHistory: [AccountBalance]?

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Init

    init(
        name: String,
        category: AccountCategory,
        balance: Decimal = 0,
        interestRate: Decimal? = nil,
        minimumPayment: Decimal? = nil,
        creditLimitOrOriginalBalance: Decimal? = nil,
        statementDay: Int? = nil,
        statementBalance: Decimal? = nil,
        sortOrder: Int = 0,
        isActive: Bool = true,
        note: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.balance = balance
        self.balanceUpdatedAt = .now
        self.interestRate = interestRate
        self.minimumPayment = minimumPayment
        self.creditLimitOrOriginalBalance = creditLimitOrOriginalBalance
        self.statementDay = statementDay
        self.statementBalance = statementBalance
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.note = note
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Computed

    var category: AccountCategory {
        get { AccountCategory(rawValue: categoryRaw) ?? .debit }
        set { categoryRaw = newValue.rawValue }
    }

    var kind: AccountCategory.Kind { category.kind }
    var isAsset: Bool { category.isAsset }

    /// Days since the user last updated the balance. Drives reconciliation
    /// nudges and the staleness indicator on account rows.
    var daysSinceBalanceUpdate: Int {
        let seconds = Date.now.timeIntervalSince(balanceUpdatedAt)
        return max(0, Int(seconds / 86_400))
    }

    /// Credit card utilization: balance / creditLimit. Nil if not a credit
    /// card or limit unknown.
    var utilization: Double? {
        guard kind == .credit,
              let limit = creditLimitOrOriginalBalance,
              limit > 0
        else { return nil }
        return NSDecimalNumber(decimal: balance)
            .dividing(by: NSDecimalNumber(decimal: limit))
            .doubleValue
    }

    // MARK: - Balance Mutators

    /// Update the balance and record a new AccountBalance snapshot.
    /// Returns the new snapshot so the caller can insert it.
    @discardableResult
    func recordNewBalance(_ newBalance: Decimal, at date: Date = .now, note: String? = nil) -> AccountBalance {
        balance = newBalance
        balanceUpdatedAt = date
        updatedAt = .now
        return AccountBalance(account: self, balance: newBalance, recordedAt: date, note: note)
    }

    func touch() { updatedAt = .now }
}
