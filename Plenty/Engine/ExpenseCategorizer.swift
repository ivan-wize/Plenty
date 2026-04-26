//
//  ExpenseCategorizer.swift
//  Plenty
//
//  Target path: Plenty/Engine/ExpenseCategorizer.swift
//
//  Rule-based keyword classifier. Falls back for users without Apple
//  Intelligence (see AIExpenseCategorizer for the AI path) and serves
//  as the first-pass guess before AI refinement.
//
//  Port from Left with the 10-category trim already baked in.
//

import Foundation

enum ExpenseCategorizer {

    /// Best-effort category detection from a transaction name/merchant.
    /// Returns `.other` if no rule matches.
    static func detect(from name: String) -> TransactionCategory {
        let lower = name.lowercased()

        for (category, keywords) in keywordRules {
            for keyword in keywords where lower.contains(keyword) {
                return category
            }
        }
        return .other
    }

    // MARK: - Keyword Rules

    private static let keywordRules: [(TransactionCategory, [String])] = [
        (.groceries, [
            "trader joe", "whole foods", "safeway", "kroger", "aldi",
            "publix", "wegmans", "costco", "walmart", "target",
            "grocery", "groceries", "supermarket", "market basket"
        ]),
        (.dining, [
            "restaurant", "cafe", "café", "coffee", "starbucks",
            "doordash", "uber eats", "grubhub", "postmates", "chipotle",
            "mcdonald", "taco bell", "pizza", "sushi", "thai", "burger",
            "dunkin", "peet", "philz", "blue bottle", "chick-fil-a",
            "panera", "sweetgreen", "shake shack", "in-n-out",
            "lunch", "dinner", "brunch", "breakfast", "food"
        ]),
        (.transportation, [
            "uber", "lyft", "taxi", "shell", "chevron", "exxon",
            "bp ", "mobil", "arco", "76 ", "gas station", "parking",
            "toll", "dmv", "smog", "auto", "car wash", "caltrain",
            "bart", "metro", "subway", "amtrak", "transit"
        ]),
        (.shopping, [
            "amazon", "apple store", "apple.com", "best buy", "target",
            "walmart", "sephora", "ulta", "nordstrom", "macy",
            "bloomingdale", "zara", "uniqlo", "gap ", "old navy",
            "nike", "adidas", "etsy", "ebay", "shop", "store"
        ]),
        (.entertainment, [
            "netflix", "spotify", "hulu", "disney+", "hbo", "apple tv",
            "movie", "cinema", "ticketmaster", "stubhub", "eventbrite",
            "concert", "theater", "theatre", "museum", "steam",
            "playstation", "xbox", "nintendo", "spotify"
        ]),
        (.health, [
            "cvs", "walgreens", "rite aid", "pharmacy", "doctor",
            "dentist", "hospital", "clinic", "urgent care", "therapy",
            "kaiser", "blue cross", "health", "medical", "vision",
            "dental", "gym", "yoga", "peloton", "equinox", "orangetheory",
            "classpass", "fitness"
        ]),
        (.housing, [
            "rent", "mortgage", "hoa", "home depot", "lowe", "ikea",
            "furniture", "plumber", "electrician", "repair", "landlord",
            "property"
        ]),
        (.utilities, [
            "pg&e", "pge", "con edison", "comed", "duke energy",
            "electric", "water", "gas company", "pge ", "verizon",
            "at&t", "t-mobile", "tmobile", "comcast", "xfinity",
            "spectrum", "internet", "wifi", "phone bill"
        ]),
        (.subscriptions, [
            "patreon", "substack", "medium", "github", "figma",
            "adobe", "1password", "lastpass", "dropbox", "notion",
            "linear", "prime membership", "amazon prime"
        ]),
    ]
}
