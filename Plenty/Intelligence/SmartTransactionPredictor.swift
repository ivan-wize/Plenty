//
//  SmartTransactionPredictor.swift
//  Plenty
//
//  Target path: Plenty/Intelligence/SmartTransactionPredictor.swift
//
//  Phase 10 cleanup: removed the dead `_ = median` no-op statement
//  inside the variance-penalty branch — that line was a leftover from
//  an earlier draft where `median` wasn't yet returned, and is now
//  redundant since `median` is part of the SmartPrediction return value.
//
//  Otherwise unchanged from P7: predicts a category and amount for a
//  new expense based on the user's own history, on-device, with
//  confidence scaling on match count, category agreement, and amount
//  variance.
//

import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "smart-predictor")

// MARK: - Result

struct SmartPrediction: Sendable, Equatable {

    /// Most-frequent category among matching past transactions, or nil
    /// if no clear winner.
    let category: TransactionCategory?

    /// Median amount among matching past transactions.
    let amount: Decimal?

    /// 0.0 to 1.0 — how strongly to surface this prediction. Computed
    /// from match count (more history → higher confidence) and
    /// agreement (matches that all share the same category and similar
    /// amounts → higher confidence).
    let confidence: Double

    /// Number of historical transactions that matched.
    let matchCount: Int

    /// The vendor name from the most-frequent past transaction (the
    /// matched name, not the user's typed input). Used for the inline
    /// suggestion copy: "Last time at Starbucks: $6.50."
    let displayName: String?
}

// MARK: - Predictor

@MainActor
final class SmartTransactionPredictor {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Predict category and amount for an expense with the given name.
    /// Returns nil when the input is too short or there's no history
    /// to draw from.
    func predict(for typedName: String) -> SmartPrediction? {
        let trimmed = typedName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Need at least 3 characters before predicting — anything
        // shorter is too noisy.
        guard trimmed.count >= 3 else { return nil }

        let matches = fetchMatches(for: trimmed)
        guard !matches.isEmpty else { return nil }

        return summarize(matches: matches, typedName: trimmed)
    }

    // MARK: - Fetch

    private func fetchMatches(for needle: String) -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                tx.kindRaw == "expense"
            }
        )
        guard let allExpenses = try? context.fetch(descriptor) else { return [] }

        return allExpenses.filter { tx in
            let txName = tx.name.lowercased()
            return txName.contains(needle) || needle.contains(txName)
        }
    }

    // MARK: - Summarize

    private func summarize(matches: [Transaction], typedName: String) -> SmartPrediction {

        // Group by exact name (case-insensitive) so the most-used
        // vendor wins. A user with 30 Starbucks and 1 Star Market
        // gets Starbucks suggested, not whichever happens to be first.
        var byName: [String: [Transaction]] = [:]
        for tx in matches {
            byName[tx.name.lowercased(), default: []].append(tx)
        }

        // Pick the largest cluster — the user's most repeated vendor
        // among the matches.
        let topCluster = byName.max(by: { $0.value.count < $1.value.count })
        let canonicalMatches = topCluster?.value ?? matches
        let displayName = canonicalMatches.first?.name

        // Most-frequent category across the cluster.
        var categoryCounts: [TransactionCategory: Int] = [:]
        for tx in canonicalMatches {
            if let cat = tx.category {
                categoryCounts[cat, default: 0] += 1
            }
        }
        let topCategory = categoryCounts.max(by: { $0.value < $1.value })?.key

        // Median amount.
        let amounts = canonicalMatches
            .map(\.amount)
            .sorted()
        let median: Decimal? = amounts.isEmpty ? nil : amounts[amounts.count / 2]

        // Confidence model:
        //   base = min(1.0, matchCount / 5)  → 5 matches = full base
        //   penalize disagreement: if top category is < 60% of cluster,
        //   confidence drops.
        let count = canonicalMatches.count
        var confidence = min(1.0, Double(count) / 5.0)

        if let topCount = categoryCounts.values.max() {
            let agreement = Double(topCount) / Double(max(count, 1))
            if agreement < 0.6 {
                confidence *= agreement
            }
        }

        // Penalize when median amount has high variance — if the user's
        // past Starbucks ranges from $4 to $40, we shouldn't confidently
        // suggest the median. Use coefficient of variation.
        if let median, median > 0, amounts.count >= 3 {
            let avg = amounts.reduce(Decimal.zero, +) / Decimal(amounts.count)
            let variance = amounts.reduce(Decimal.zero) { acc, x in
                let d = x - avg
                return acc + (d * d)
            } / Decimal(amounts.count)

            let cv: Double = {
                guard avg > 0 else { return 0 }
                let stdDev = sqrt(NSDecimalNumber(decimal: variance).doubleValue)
                let avgD = NSDecimalNumber(decimal: avg).doubleValue
                return stdDev / avgD
            }()
            if cv > 0.5 {
                confidence *= max(0.4, 1.0 - cv)
            }
        }

        return SmartPrediction(
            category: topCategory,
            amount: median,
            confidence: max(0, min(1, confidence)),
            matchCount: count,
            displayName: displayName
        )
    }
}
