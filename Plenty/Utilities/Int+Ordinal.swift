//
//  Int+Ordinal.swift
//  Plenty
//
//  Target path: Plenty/Utilities/Int+Ordinal.swift
//
//  Copied forward from Left v1.0 unchanged. Used wherever bill due days
//  are rendered ("Rent on the 1st").
//

import Foundation

extension Int {

    /// Returns the ordinal string for this integer.
    /// Examples: 1 → "1st", 2 → "2nd", 3 → "3rd", 4 → "4th", 21 → "21st".
    var ordinalString: String {
        let suffix: String
        switch self {
        case 1, 21, 31: suffix = "st"
        case 2, 22:     suffix = "nd"
        case 3, 23:     suffix = "rd"
        default:        suffix = "th"
        }
        return "\(self)\(suffix)"
    }
}
