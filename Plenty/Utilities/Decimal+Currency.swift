//
//  Decimal+Currency.swift
//  Plenty
//
//  Target path: Plenty/Utilities/Decimal+Currency.swift
//
//  Copied forward from Left v1.0 unchanged. Locale-aware currency
//  formatting for every Decimal that reaches the UI.
//

import Foundation

extension Decimal {

    /// Full locale-aware currency string (e.g., "$1,234.56").
    func asCurrency() -> String {
        Self.currencyFormatter.string(from: self as NSDecimalNumber) ?? "$\(self)"
    }

    /// Compact currency: drops cents for whole numbers, abbreviates thousands.
    /// Examples: "$0", "$100", "$1K", "$2.5K"
    func asShortCurrency() -> String {
        let absValue = abs(NSDecimalNumber(decimal: self).doubleValue)
        let sign = self < 0 ? "-" : ""
        let symbol = Self.currencySymbol

        if absValue >= 1000 {
            let k = absValue / 1000
            if k == k.rounded(.down) {
                return "\(sign)\(symbol)\(Int(k))K"
            } else {
                return "\(sign)\(symbol)\(String(format: "%.1f", k))K"
            }
        }

        if absValue == absValue.rounded(.down) {
            return "\(sign)\(symbol)\(Int(absValue))"
        }

        return asCurrency()
    }

    /// Currency string that drops ".00" for whole numbers.
    /// Examples: "$500", "$1,000", "$99.50"
    func asCleanCurrency() -> String {
        let dbl = NSDecimalNumber(decimal: self).doubleValue
        if dbl == dbl.rounded(.down) {
            return Self.wholeFormatter.string(from: self as NSDecimalNumber) ?? asCurrency()
        }
        return asCurrency()
    }

    // MARK: - Formatters

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }()

    private static let wholeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        f.maximumFractionDigits = 0
        return f
    }()

    static var currencySymbol: String {
        Locale.current.currencySymbol ?? "$"
    }
}
