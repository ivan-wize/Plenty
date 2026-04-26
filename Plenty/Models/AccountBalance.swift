//
//  AccountBalance.swift
//  Plenty
//
//  Target path: Plenty/Models/AccountBalance.swift
//
//  A single historical balance snapshot for an account. Every time the
//  user updates an account's balance, a new AccountBalance record is
//  created so the 6-month trend chart has points to render.
//
//  Relationship is many-to-one (many snapshots per account); the
//  inverse lives on Account.balanceHistory.
//
//  Port from Left.
//

import Foundation
import SwiftData

@Model
final class AccountBalance {

    // MARK: - Identity

    var id: UUID = UUID()

    /// Balance as positive magnitude. Sign is derived from the owning
    /// account's kind.isAsset.
    var balance: Decimal = 0

    /// When the balance was recorded.
    var recordedAt: Date = Date()

    /// Optional note. "Paid off," "Transferred in $500," etc.
    var note: String?

    // MARK: - Relationship

    /// The account this snapshot belongs to. Nullified on account delete
    /// so historical data survives account removal (useful for exports).
    @Relationship(deleteRule: .nullify)
    var account: Account?

    // MARK: - Init

    init(account: Account?, balance: Decimal, recordedAt: Date = .now, note: String? = nil) {
        self.id = UUID()
        self.account = account
        self.balance = balance
        self.recordedAt = recordedAt
        self.note = note
    }
}
