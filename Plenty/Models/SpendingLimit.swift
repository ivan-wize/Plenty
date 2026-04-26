//
//  SpendingLimit.swift
//  Plenty
//
//  Target path: Plenty/Models/SpendingLimit.swift
//
//  A per-category monthly spending limit. Optional feature; users set
//  limits on categories they want to keep tabs on. Port from Left.
//

import Foundation
import SwiftData

@Model
final class SpendingLimit {

    // MARK: - Identity

    var id: UUID = UUID()

    /// The category this limit applies to. Stored raw for CloudKit.
    var categoryRaw: String = TransactionCategory.other.rawValue

    /// Monthly limit amount. Positive magnitude.
    var monthlyLimit: Decimal = 0

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Init

    init(category: TransactionCategory, monthlyLimit: Decimal) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.monthlyLimit = monthlyLimit
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Computed

    var category: TransactionCategory? {
        TransactionCategory(rawValue: categoryRaw)
    }
}
