//
//  CSVColumnDetector.swift
//  Plenty
//
//  Target path: Plenty/Import/CSVColumnDetector.swift
//
//  Identifies which CSV column is date, amount, and description by
//  combining header-name matching with content sampling. Also detects
//  the sign convention: single signed amount vs separate debit/credit
//  columns vs amount + sign indicator.
//
//  Confidence scoring: 0-100. Headers that match strong patterns score
//  high. Content matching alone scores lower. Below 50, the column
//  detection is shown as a suggestion the user should verify.
//

import Foundation

enum CSVColumnDetector {

    // MARK: - Sign Convention

    enum SignConvention: Sendable {
        /// Single column with positive (income) and negative (expense) values.
        case signedAmount(column: Int)

        /// Two columns: separate debits and credits.
        case debitCreditSplit(debitColumn: Int, creditColumn: Int)

        /// Amount column always positive plus a separate column with DR/CR or +/- indicator.
        case amountPlusIndicator(amountColumn: Int, indicatorColumn: Int)
    }

    // MARK: - Output

    struct Mapping: Sendable {
        let dateColumn: Int
        let descriptionColumn: Int
        let signConvention: SignConvention
        let dateConfidence: Int          // 0-100
        let descriptionConfidence: Int   // 0-100
        let amountConfidence: Int        // 0-100

        var allHighConfidence: Bool {
            dateConfidence >= 75 && descriptionConfidence >= 75 && amountConfidence >= 75
        }
    }

    // MARK: - Public

    /// Detect column mapping from headers and a sample of data rows.
    /// Returns nil if no plausible date or amount column can be found.
    static func detect(headers: [String], sampleRows: [[String]]) -> Mapping? {
        let normalizedHeaders = headers.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }

        // Date column: header match strongest, then content match.
        guard let dateResult = detectDateColumn(headers: normalizedHeaders, samples: sampleRows) else {
            return nil
        }

        // Description column: header match (description, memo, payee, name).
        guard let descResult = detectDescriptionColumn(headers: normalizedHeaders, samples: sampleRows) else {
            return nil
        }

        // Sign convention: try debit/credit split first (more specific),
        // then signed amount, then amount+indicator.
        guard let amountResult = detectAmountColumns(headers: normalizedHeaders, samples: sampleRows) else {
            return nil
        }

        return Mapping(
            dateColumn: dateResult.column,
            descriptionColumn: descResult.column,
            signConvention: amountResult.convention,
            dateConfidence: dateResult.confidence,
            descriptionConfidence: descResult.confidence,
            amountConfidence: amountResult.confidence
        )
    }

    // MARK: - Date Column

    private static let dateHeaderKeywords = [
        "date", "transaction date", "posted date", "post date", "trans date", "settlement date"
    ]

    private static func detectDateColumn(headers: [String], samples: [[String]]) -> (column: Int, confidence: Int)? {
        // Header match
        for (index, header) in headers.enumerated() {
            if dateHeaderKeywords.contains(header) {
                return (index, 95)
            }
            if dateHeaderKeywords.contains(where: { header.contains($0) }) {
                return (index, 80)
            }
        }

        // Content match: column where sample values parse as dates
        var bestColumn: Int?
        var bestParseRate = 0.0
        for index in 0..<headers.count {
            let columnSamples = samples.compactMap { row in row.indices.contains(index) ? row[index] : nil }
            let parsed = columnSamples.filter { sample in
                if case .parsed = CSVDateParser.parse(sample) { return true }
                if case .ambiguous = CSVDateParser.parse(sample) { return true }
                return false
            }
            let rate = columnSamples.isEmpty ? 0 : Double(parsed.count) / Double(columnSamples.count)
            if rate > bestParseRate {
                bestParseRate = rate
                bestColumn = index
            }
        }

        guard let bestColumn, bestParseRate >= 0.7 else { return nil }
        let confidence = Int(bestParseRate * 70)  // content match capped at 70
        return (bestColumn, confidence)
    }

    // MARK: - Description Column

    private static let descriptionHeaderKeywords = [
        "description", "memo", "payee", "merchant", "name", "details", "narrative", "transaction", "particulars"
    ]

    private static func detectDescriptionColumn(headers: [String], samples: [[String]]) -> (column: Int, confidence: Int)? {
        // Header match
        for (index, header) in headers.enumerated() {
            if descriptionHeaderKeywords.contains(header) {
                return (index, 90)
            }
            if descriptionHeaderKeywords.contains(where: { header.contains($0) }) {
                return (index, 75)
            }
        }

        // Content match: column with the longest average string length that
        // doesn't parse as numeric or date.
        var bestColumn: Int?
        var bestAvgLength = 0
        for index in 0..<headers.count {
            let columnSamples = samples.compactMap { row in row.indices.contains(index) ? row[index] : nil }
            let nonNumeric = columnSamples.filter { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) == nil }
            guard nonNumeric.count >= columnSamples.count / 2 else { continue }

            let avgLength = nonNumeric.isEmpty ? 0 : nonNumeric.map(\.count).reduce(0, +) / nonNumeric.count
            if avgLength > bestAvgLength {
                bestAvgLength = avgLength
                bestColumn = index
            }
        }

        guard let bestColumn, bestAvgLength >= 4 else { return nil }
        return (bestColumn, 60)  // content-match confidence
    }

    // MARK: - Amount Columns

    private static let amountHeaderKeywords = ["amount", "transaction amount"]
    private static let debitHeaderKeywords = ["debit", "withdrawal", "withdrawals", "money out", "outflow"]
    private static let creditHeaderKeywords = ["credit", "deposit", "deposits", "money in", "inflow"]

    private struct AmountResult {
        let convention: SignConvention
        let confidence: Int
    }

    private static func detectAmountColumns(headers: [String], samples: [[String]]) -> AmountResult? {
        var debitColumn: Int?
        var creditColumn: Int?
        var amountColumn: Int?

        for (index, header) in headers.enumerated() {
            if debitHeaderKeywords.contains(where: { header.contains($0) }) {
                debitColumn = index
            } else if creditHeaderKeywords.contains(where: { header.contains($0) }) {
                creditColumn = index
            } else if amountHeaderKeywords.contains(header)
                        || amountHeaderKeywords.contains(where: { header.contains($0) }) {
                amountColumn = index
            }
        }

        // Debit + credit split is most specific.
        if let debitColumn, let creditColumn {
            return AmountResult(
                convention: .debitCreditSplit(debitColumn: debitColumn, creditColumn: creditColumn),
                confidence: 95
            )
        }

        // Single amount column.
        if let amountColumn {
            return AmountResult(
                convention: .signedAmount(column: amountColumn),
                confidence: 90
            )
        }

        // Content fallback: find a column where most values parse as Decimal.
        var bestColumn: Int?
        var bestParseRate = 0.0
        for index in 0..<headers.count {
            let columnSamples = samples.compactMap { row in row.indices.contains(index) ? row[index] : nil }
            let numeric = columnSamples.filter { sample in
                let cleaned = sample.replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: ",", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return Decimal(string: cleaned) != nil && !cleaned.isEmpty
            }
            let rate = columnSamples.isEmpty ? 0 : Double(numeric.count) / Double(columnSamples.count)
            if rate > bestParseRate {
                bestParseRate = rate
                bestColumn = index
            }
        }

        guard let bestColumn, bestParseRate >= 0.7 else { return nil }
        return AmountResult(
            convention: .signedAmount(column: bestColumn),
            confidence: Int(bestParseRate * 60)
        )
    }
}
