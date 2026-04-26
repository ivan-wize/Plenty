//
//  AIExpenseCategorizer.swift
//  Plenty
//
//  Target path: Plenty/Intelligence/AIExpenseCategorizer.swift
//
//  On-device expense categorization via Foundation Models (iOS 26+).
//
//  Port from Left v3 (the 10-category trim). Uses
//  SystemLanguageModel.default. The @Guide constraint pins the output
//  to the exact set of category raw values, so the model can't
//  hallucinate something we can't decode.
//
//  Returns nil on:
//    • Empty input
//    • Apple Intelligence unavailable on this device
//    • Any session error (context length, throttling, etc.)
//
//  Callers are expected to fall through to ExpenseCategorizer (rule-
//  based) on nil.
//

import Foundation
import FoundationModels

// MARK: - Generable Output

@Generable
struct CategoryPrediction {
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

// MARK: - Categorizer

enum AIExpenseCategorizer {

    /// Classify a transaction name using the on-device general LLM.
    ///
    /// - Parameter transactionName: Raw merchant name or short description.
    /// - Returns: A `TransactionCategory` on success, `nil` on model
    ///   unavailability or any session error. Callers should fall back
    ///   to `ExpenseCategorizer.detect(from:)` on nil.
    static func categorize(_ transactionName: String) async -> TransactionCategory? {
        let trimmed = transactionName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        do {
            let session = LanguageModelSession(
                model: .default,
                instructions: """
                You are a financial transaction classifier. Given a transaction \
                name, output the single most appropriate spending category. \
                Use only the category values listed. Output nothing else.

                Category reference:
                • groceries: supermarkets, grocery stores, Trader Joe's, \
                  Whole Foods, Costco, Walmart, Safeway, Kroger, Aldi, \
                  weekly food shopping
                • dining: restaurants, cafés, coffee shops, fast food, \
                  food delivery (DoorDash, Uber Eats, Grubhub), bars, \
                  breweries, anywhere you eat or drink out
                • transportation: gas stations, Uber, Lyft, parking, tolls, \
                  public transit, trains, taxi, car wash, auto parts, DMV
                • shopping: clothes, electronics, Amazon, Target, Best Buy, \
                  Apple Store, Sephora, Ulta, Etsy, household goods, gifts, \
                  haircuts, salons, dry cleaning
                • entertainment: movies, concerts, theatre, museums, \
                  Ticketmaster, gaming (Steam, PlayStation, Xbox), hobbies, \
                  going out, events
                • health: doctor, dentist, therapy, pharmacy, CVS, Walgreens, \
                  hospital, urgent care, prescriptions, vision, dental, gym, \
                  fitness classes, Peloton, yoga
                • housing: rent, mortgage, HOA, home repairs, plumber, \
                  electrician, furniture, IKEA, Home Depot, Lowe's, \
                  moving expenses
                • utilities: electricity, water, gas (heating), trash, \
                  power, phone bill, internet, WiFi, cable, Verizon, \
                  AT&T, T-Mobile, Comcast, Xfinity
                • subscriptions: Netflix, Spotify, Hulu, Disney+, HBO, \
                  Apple Music, YouTube Premium, Amazon Prime, Patreon, \
                  Audible, any recurring digital service or membership
                • other: anything that clearly does not fit above
                """
            )

            let prompt = "Transaction: \"\(trimmed)\""

            let response = try await session.respond(
                to: prompt,
                generating: CategoryPrediction.self
            )

            return TransactionCategory(rawValue: response.content.category)

        } catch {
            // Any model error. Return nil so caller falls back to rules.
            return nil
        }
    }
}
