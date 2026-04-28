//
//  AIBillParser.swift
//  Plenty
//
//  Target path: Plenty/Intelligence/AIBillParser.swift
//
//  Phase 5 (v2): on-device parser for bills. Mirrors AIReceiptParser
//  in shape — same Foundation Models @Generable approach — but
//  extracts bill-specific fields: vendor, amount due, due date,
//  recurrence, category.
//
//  Conventions (kept consistent with AIReceiptParser):
//    • Returns nil on availability failures or empty input
//    • Every output field is optional; the model returns nil rather
//      than guessing
//    • Confidence threshold is implicit in the Guide constraints —
//      anything outside the constrained set surfaces as nil
//

import Foundation
import FoundationModels
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "ai-bill-parser")

@MainActor
enum AIBillParser {

    // MARK: - Public API

    static func parse(_ ocrText: String) async -> BillDraft? {
        let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Availability check — if Foundation Models isn't usable on
        // this device or the user's account, fall through. The caller
        // should ask for manual entry.
        guard SystemLanguageModel.default.availability == .available else {
            logger.info("AIBillParser unavailable: Foundation Models not ready")
            return nil
        }

        do {
            let session = LanguageModelSession {
                Self.systemInstructions
            }

            let response = try await session.respond(
                to: Prompt {
                    "Extract structured fields from this bill or invoice text:"
                    "\n\n"
                    trimmed.prefix(4000)
                },
                generating: BillExtraction.self
            )

            return Self.makeDraft(from: response.content)

        } catch {
            logger.error("AIBillParser failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Generable Schema

    @Generable
    struct BillExtraction {

        @Guide(description: "The company or organization billing the customer. Examples: 'Pacific Gas & Electric', 'Comcast', 'State Farm'. Nil if unclear.")
        var vendor: String?

        @Guide(description: "The total amount due as a positive number. Use the 'Amount Due' or 'Total Due' field, not the prior balance or last payment. Nil if unclear.")
        var amountDue: Double?

        @Guide(description: "The due date in ISO format (YYYY-MM-DD). Nil if no due date is shown.")
        var dueDate: String?

        @Guide(
            description: "How often this bill repeats. Use 'monthly' for utilities, rent, internet, subscriptions. 'quarterly' for HOA dues or insurance paid four times a year. 'annually' for property tax, annual insurance premiums. 'unknown' if the document doesn't make it clear.",
            .anyOf(["monthly", "quarterly", "annually", "unknown"])
        )
        var recurrence: String

        @Guide(
            description: "Best-fit expense category for this bill.",
            .anyOf([
                "housing",
                "utilities",
                "internet",
                "phone",
                "subscriptions",
                "insurance",
                "taxes",
                "other"
            ])
        )
        var category: String
    }

    // MARK: - Translation

    private static func makeDraft(from extraction: BillExtraction) -> BillDraft {
        let amount: Decimal? = extraction.amountDue.flatMap { value in
            guard value > 0 else { return nil }
            return Decimal(value)
        }

        let (dueDay, _) = parseDueDate(extraction.dueDate)
        let recurrence = mapRecurrence(extraction.recurrence)
        let category = mapCategory(extraction.category)

        return BillDraft(
            vendor: extraction.vendor?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            amount: amount,
            dueDay: dueDay,
            recurrence: recurrence,
            category: category
        )
    }

    private static func parseDueDate(_ iso: String?) -> (day: Int?, date: Date?) {
        guard let iso, !iso.isEmpty else { return (nil, nil) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        guard let date = formatter.date(from: iso) else { return (nil, nil) }
        let day = Calendar.current.component(.day, from: date)
        return (day, date)
    }

    private static func mapRecurrence(_ raw: String) -> BillDraft.Recurrence? {
        switch raw.lowercased() {
        case "monthly":   return .monthly
        case "quarterly": return .quarterly
        case "annually":  return .annually
        default:          return nil
        }
    }

    private static func mapCategory(_ raw: String) -> TransactionCategory? {
        switch raw.lowercased() {
        case "housing":       return .housing
        case "utilities":     return .utilities
        case "internet":      return .utilities
        case "phone":         return .utilities
        case "subscriptions": return .subscriptions
        case "insurance":     return .insurance
        case "taxes":         return .taxes
        default:              return nil
        }
    }

    // MARK: - System Instructions

    private static let systemInstructions = """
    You extract structured data from bills, invoices, and statements that have \
    been captured via OCR. Be precise. When a field isn't clearly present, \
    return nil rather than guessing.

    Distinguish "amount due" from "previous balance," "last payment," "credit," \
    or "minimum payment due." Only extract the current amount the customer owes.

    For the due date, use the explicit due date on the statement — not the \
    statement date or the billing period. Format as YYYY-MM-DD.

    For recurrence, infer from context: monthly utilities, monthly subscriptions, \
    quarterly insurance, annual property tax, etc. Use "unknown" if it isn't clear.
    """
}

// MARK: - String Helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
