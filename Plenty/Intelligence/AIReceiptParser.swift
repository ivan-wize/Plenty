//
//  AIReceiptParser.swift
//  Plenty
//
//  Target path: Plenty/Intelligence/AIReceiptParser.swift
//
//  On-device receipt parsing via Foundation Models (iOS 26+).
//
//  Input: the raw OCR text from a scanned receipt (everything Vision
//  recognized, in reading order).
//
//  Output: a `ReceiptDraft` with merchant, total amount, date, and a
//  guess at the spending category. All four fields are optional —
//  the parser returns nil only when the model is unavailable or the
//  session errors. When a field can't be extracted with confidence,
//  the model is instructed to return null for that field, and the
//  caller leaves the corresponding sheet field blank for the user to
//  fill manually.
//
//  Returns nil on:
//    • Empty input
//    • Apple Intelligence unavailable on this device
//    • Any session error (context length, throttling, etc.)
//
//  Callers fall through to leaving fields empty on nil — there's no
//  good rule-based fallback for receipt structure.
//

import Foundation
import FoundationModels

// MARK: - Generable Output

@Generable
struct ReceiptExtraction {

    @Guide(description: "The merchant or store name as it appears at the top of the receipt. Strip any address, phone number, or transaction ID. Examples: 'Trader Joe's', 'Shell', 'Starbucks'. Return null if no clear merchant.")
    var merchant: String?

    @Guide(description: "The grand total amount paid, including tax and tip. As a decimal number, no currency symbol. Example: 42.18. Look for 'Total', 'Amount Due', 'Balance', usually the last and largest dollar value. Return null if no total found.")
    var totalAmount: Double?

    @Guide(description: "Transaction date in ISO format YYYY-MM-DD. Example: '2026-04-15'. If the receipt shows only month/day, infer the most recent year. Return null if no date found.")
    var date: String?

    @Guide(
        .anyOf([
            "groceries",
            "dining",
            "transportation",
            "shopping",
            "entertainment",
            "health",
            "housing",
            "utilities",
            "subscriptions",
            "other"
        ])
    )
    var category: String
}

// MARK: - Public Result

struct ReceiptDraft: Sendable, Equatable {
    var merchant: String?
    var totalAmount: Decimal?
    var date: Date?
    var category: TransactionCategory?
}

// MARK: - Parser

enum AIReceiptParser {

    /// Parse OCR'd receipt text into a structured ReceiptDraft.
    ///
    /// - Parameter ocrText: The raw recognized text from Vision, in
    ///   reading order. Pass the full string; the model handles noise.
    /// - Returns: A ReceiptDraft with fields the model could extract,
    ///   or nil on model unavailability or session error.
    static func parse(_ ocrText: String) async -> ReceiptDraft? {
        let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: """
                You parse retail receipts. Given the OCR text of a single \
                receipt (in reading order, with line breaks preserved), extract:
                merchant name, grand total, transaction date, and a category.

                Rules:
                • Merchant: the business name, usually the first or second line. \
                  Strip address, phone, store number. If unsure, return null.
                • Total: the grand total including tax and tip. Look for the \
                  largest dollar value labelled 'Total', 'Amount', 'Balance', \
                  'Charge'. Skip subtotals and individual line items.
                • Date: when the transaction occurred. ISO format. If only \
                  month/day shown, infer the most recent year.
                • Category: pick from the allowed values based on the merchant \
                  and items. Default to 'other' if no clear fit.

                Output null for any field you cannot extract with confidence. \
                The user will fill blanks manually.
                """
            )

            let prompt = """
            Receipt OCR text:
            ---
            \(trimmed)
            ---
            """

            let response = try await session.respond(
                to: prompt,
                generating: ReceiptExtraction.self
            )

            return ReceiptDraft(
                merchant: cleanMerchant(response.content.merchant),
                totalAmount: parseAmount(response.content.totalAmount),
                date: parseDate(response.content.date),
                category: TransactionCategory(rawValue: response.content.category)
            )

        } catch {
            return nil
        }
    }

    // MARK: - Field Cleaners

    private static func cleanMerchant(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }
        // Title-case each word for consistency.
        let words = trimmed.split(separator: " ").map { word -> String in
            let lower = word.lowercased()
            // Preserve all-caps short words like "USA", "BBQ"
            if word.count <= 4 && word == word.uppercased() { return String(word) }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }
        return words.joined(separator: " ")
    }

    private static func parseAmount(_ raw: Double?) -> Decimal? {
        guard let raw, raw > 0, raw < 100_000 else { return nil }
        // Round to 2 decimal places.
        let rounded = (raw * 100).rounded() / 100
        return Decimal(rounded)
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        if let date = formatter.date(from: trimmed) {
            // Sanity check: not in the future, not before year 2000.
            let now = Date.now
            let earliest = Calendar.current.date(from: DateComponents(year: 2000)) ?? .distantPast
            guard date <= now, date >= earliest else { return nil }
            return date
        }
        return nil
    }
}
