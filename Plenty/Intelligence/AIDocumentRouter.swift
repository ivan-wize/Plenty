//
//  AIDocumentRouter.swift
//  Plenty
//
//  Target path: Plenty/Intelligence/AIDocumentRouter.swift
//
//  Phase 5 (v2): the classifier that sits in front of AIReceiptParser
//  and AIBillParser. Looks at OCR text and decides whether it should
//  be parsed as a receipt or a bill (or fall through to manual when
//  it's neither / unclear).
//
//  Heuristic before AI:
//  Some documents are obvious from keyword presence alone (e.g. a
//  document with "Amount Due" and a future date is a bill; a document
//  with "Subtotal", "Tax", "Total" in close sequence is a receipt).
//  We try a fast keyword pass first to save Foundation Models tokens
//  and latency. If the heuristic returns .unknown, we fall through to
//  the AI classifier.
//

import Foundation
import FoundationModels
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "ai-document-router")

@MainActor
enum AIDocumentRouter {

    // MARK: - Types

    enum DocumentKind: String, Sendable {
        case receipt
        case bill
        case unknown
    }

    // MARK: - Public API

    static func classify(_ ocrText: String) async -> DocumentKind {
        let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }

        // 1. Fast keyword heuristic
        let heuristic = heuristicClassify(trimmed)
        if heuristic != .unknown { return heuristic }

        // 2. AI classifier fallback
        guard SystemLanguageModel.default.availability == .available else {
            logger.info("Document router: Foundation Models unavailable, returning .unknown")
            return .unknown
        }

        do {
            let session = LanguageModelSession {
                Self.systemInstructions
            }
            let response = try await session.respond(
                to: Prompt {
                    "Classify the following document text:"
                    "\n\n"
                    String(trimmed.prefix(2000))
                },
                generating: Classification.self
            )
            switch response.content.kind.lowercased() {
            case "receipt": return .receipt
            case "bill":    return .bill
            default:        return .unknown
            }
        } catch {
            logger.error("Document router AI failed: \(error.localizedDescription)")
            return .unknown
        }
    }

    // MARK: - Heuristic

    /// Cheap keyword-based classification. Catches the common cases
    /// without burning Foundation Models tokens.
    static func heuristicClassify(_ text: String) -> DocumentKind {
        let lower = text.lowercased()

        // Strong receipt signals
        let receiptSignals = [
            "subtotal", "total due:",
            "thank you for your purchase",
            "tip", "gratuity",
            "merchant copy", "customer copy",
            "auth code", "approval code"
        ]

        // Strong bill signals
        let billSignals = [
            "amount due",
            "payment due",
            "due date",
            "account number",
            "statement date",
            "billing period",
            "service period",
            "previous balance",
            "minimum payment due",
            "autopay"
        ]

        let receiptHits = receiptSignals.filter { lower.contains($0) }.count
        let billHits = billSignals.filter { lower.contains($0) }.count

        // Decisive signals
        if billHits >= 2 && billHits > receiptHits {
            return .bill
        }
        if receiptHits >= 2 && receiptHits > billHits {
            return .receipt
        }

        // Single very strong signal
        if lower.contains("amount due") || lower.contains("statement date") {
            return .bill
        }
        if lower.contains("thank you for your purchase") {
            return .receipt
        }

        return .unknown
    }

    // MARK: - Generable

    @Generable
    struct Classification {

        @Guide(
            description: "The kind of document captured. 'receipt' for a point-of-sale transaction the customer has just paid. 'bill' for a statement or invoice the customer owes and will pay later. 'unknown' if neither is clear.",
            .anyOf(["receipt", "bill", "unknown"])
        )
        var kind: String
    }

    // MARK: - Instructions

    private static let systemInstructions = """
    You classify financial documents captured via OCR. Decide whether the text \
    represents a receipt (immediate payment for a purchase, e.g. a restaurant \
    or store transaction) or a bill (a statement showing money owed, due in the \
    future, e.g. a utility bill or invoice).

    Receipts typically include line items, subtotal, tax, tip or gratuity, and \
    "thank you" language. Bills typically include "Amount Due," a due date, \
    account numbers, billing periods, and prior balance information.

    If the document is something else entirely (a packing slip, a menu, a \
    notice), return "unknown."
    """
}
