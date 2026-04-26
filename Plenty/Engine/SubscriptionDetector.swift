//
//  SubscriptionDetector.swift
//  Plenty
//
//  Target path: Plenty/Subscriptions/SubscriptionDetector.swift
//
//  Pure analyzer. Given an array of transactions, finds repeating
//  merchants and returns DetectedSubscription candidates with cadence
//  and typical amount. No data writes — caller decides whether to
//  persist.
//
//  Heuristic, not AI:
//    1. Normalize transaction names (lowercase, strip common noise:
//       store IDs, dates, transaction numbers)
//    2. Group transactions by normalized name
//    3. For each group with ≥3 occurrences, analyze gaps between dates
//    4. Classify cadence: weekly (5-9 days), monthly (25-35 days),
//       annual (340-380 days)
//    5. Compute typical amount as median across group
//    6. Filter out groups already represented as confirmed Subscriptions
//
//  Approach favors specificity over recall — better to miss a
//  subscription than to falsely flag groceries as one.
//

import Foundation

enum SubscriptionDetector {

    // MARK: - Output

    struct DetectedSubscription: Identifiable, Sendable {
        let id = UUID()
        let merchantName: String
        let normalizedPattern: String
        let typicalAmount: Decimal
        let cadence: Subscription.Cadence
        let lastChargeDate: Date
        let chargeCount: Int
    }

    // MARK: - Public

    /// Analyze transactions to find subscription candidates. Excludes
    /// any that already have a matching confirmed Subscription.
    static func detect(
        in transactions: [Transaction],
        existing subscriptions: [Subscription]
    ) -> [DetectedSubscription] {
        // Only analyze .expense and .bill transactions.
        let candidates = transactions.filter { $0.kind == .expense || $0.kind == .bill }

        // Group by normalized name.
        let grouped = Dictionary(grouping: candidates) { tx in
            normalize(tx.name)
        }

        let existingPatterns = Set(subscriptions.map { $0.rawMerchantPattern })

        var results: [DetectedSubscription] = []

        for (pattern, group) in grouped {
            // Skip if user already confirmed/dismissed this pattern.
            if existingPatterns.contains(pattern) { continue }

            // Need at least 3 occurrences to confidently call it recurring.
            guard group.count >= 3 else { continue }

            let sorted = group.sorted { $0.date < $1.date }

            // Compute gap median.
            let gaps = zip(sorted.dropFirst(), sorted).map { newer, older in
                Calendar.current.dateComponents([.day], from: older.date, to: newer.date).day ?? 0
            }
            guard let medianGap = median(gaps) else { continue }

            guard let cadence = classify(gapDays: medianGap) else { continue }

            // Median amount.
            let amounts = sorted.map { $0.amount }
            let medianAmount = median(amounts) ?? sorted[0].amount

            // Display name: most common original name in group.
            let displayName = mostCommonName(in: sorted)

            results.append(DetectedSubscription(
                merchantName: displayName,
                normalizedPattern: pattern,
                typicalAmount: medianAmount,
                cadence: cadence,
                lastChargeDate: sorted.last?.date ?? .now,
                chargeCount: sorted.count
            ))
        }

        return results.sorted { $0.lastChargeDate > $1.lastChargeDate }
    }

    // MARK: - Normalization

    /// Reduce a transaction name to a stable comparison key. Strips
    /// trailing digits (store IDs), dates, transaction numbers, and
    /// extra whitespace. Lowercased.
    static func normalize(_ name: String) -> String {
        var s = name.lowercased()

        // Strip common patterns: trailing digits, date stamps, store IDs.
        // Examples:
        //   "NETFLIX.COM 12/15"   → "netflix.com"
        //   "Spotify USA 8x9k2"   → "spotify usa"
        //   "AMZN MKTPLACE 2839"  → "amzn mktplace"

        // Strip common date formats.
        let datePatterns = [
            #"\d{1,2}/\d{1,2}(/\d{2,4})?"#,
            #"\d{1,2}-\d{1,2}(-\d{2,4})?"#,
            #"\b\d{6,}\b"#,            // long digit runs (txn IDs)
            #"\b[a-z0-9]{6,}\b"#,      // alphanumeric reference codes
        ]
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(s.startIndex..., in: s)
                s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
            }
        }

        // Collapse whitespace, trim.
        s = s.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Cadence Classification

    private static func classify(gapDays: Int) -> Subscription.Cadence? {
        switch gapDays {
        case 5...9:    return .weekly
        case 25...35:  return .monthly
        case 340...380: return .annual
        default:       return nil
        }
    }

    // MARK: - Stats

    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }

    private static func median(_ values: [Decimal]) -> Decimal? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }

    // MARK: - Display Name

    private static func mostCommonName(in transactions: [Transaction]) -> String {
        let counts = transactions.reduce(into: [String: Int]()) { dict, tx in
            dict[tx.name, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? transactions.first?.name ?? ""
    }
}
