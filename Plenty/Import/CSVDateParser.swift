//
//  CSVDateParser.swift
//  Plenty
//
//  Target path: Plenty/Import/CSVDateParser.swift
//
//  Tries multiple date formats in priority order. Returns the parsed
//  Date plus the format that succeeded so the rest of the import
//  session can apply it consistently.
//
//  Ambiguity handling: if a string could parse as MM/DD/YYYY OR
//  DD/MM/YYYY (e.g. "01/02/2025"), the parser returns an Ambiguous
//  result and the caller surfaces a picker to the user. Never silently
//  guess on ambiguous dates — wrong dates ruin a budget app.
//

import Foundation

enum CSVDateParser {

    // MARK: - Format Catalog

    enum Format: String, CaseIterable, Identifiable, Sendable {
        case isoDate                = "yyyy-MM-dd"
        case usSlashShort           = "M/d/yy"
        case usSlashLong            = "M/d/yyyy"
        case usDashShort            = "M-d-yy"
        case usDashLong             = "M-d-yyyy"
        case euSlashShort           = "d/M/yy"
        case euSlashLong            = "d/M/yyyy"
        case euDashShort            = "d-M-yy"
        case euDashLong             = "d-M-yyyy"
        case isoDateTimeSpace       = "yyyy-MM-dd HH:mm:ss"
        case isoDateTimeT           = "yyyy-MM-dd'T'HH:mm:ss"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .isoDate, .isoDateTimeSpace, .isoDateTimeT:
                return "ISO (YYYY-MM-DD)"
            case .usSlashShort, .usSlashLong, .usDashShort, .usDashLong:
                return "US (MM/DD/YYYY)"
            case .euSlashShort, .euSlashLong, .euDashShort, .euDashLong:
                return "EU (DD/MM/YYYY)"
            }
        }

        /// Whether this format has region ambiguity with a sibling
        /// (US dates with day ≤ 12 look like EU dates).
        var hasRegionAmbiguity: Bool {
            switch self {
            case .usSlashShort, .usSlashLong, .usDashShort, .usDashLong,
                 .euSlashShort, .euSlashLong, .euDashShort, .euDashLong:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Result

    enum ParseResult: Equatable {
        case parsed(date: Date, format: Format)
        case ambiguous(usDate: Date, euDate: Date)
        case failed
    }

    // MARK: - Public

    /// Parse a single date string. Returns either a single match, an
    /// ambiguous pair (US vs EU), or failure.
    static func parse(_ string: String, preferredFormat: Format? = nil) -> ParseResult {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failed }

        // If caller has a preferred format from a previous successful
        // parse, try that first.
        if let preferredFormat, let date = tryFormat(preferredFormat, on: trimmed) {
            return .parsed(date: date, format: preferredFormat)
        }

        // Try unambiguous formats first.
        for format in Format.allCases where !format.hasRegionAmbiguity {
            if let date = tryFormat(format, on: trimmed) {
                return .parsed(date: date, format: format)
            }
        }

        // Try US and EU. If both succeed and give different dates,
        // surface ambiguity to the user.
        let usResult = tryFirstSuccess(formats: [.usSlashLong, .usSlashShort, .usDashLong, .usDashShort], on: trimmed)
        let euResult = tryFirstSuccess(formats: [.euSlashLong, .euSlashShort, .euDashLong, .euDashShort], on: trimmed)

        switch (usResult, euResult) {
        case (let usMatch?, let euMatch?):
            if Calendar.current.isDate(usMatch.date, inSameDayAs: euMatch.date) {
                // Same date both ways (e.g. "07/15/2025" — only valid as US).
                return .parsed(date: usMatch.date, format: usMatch.format)
            } else {
                return .ambiguous(usDate: usMatch.date, euDate: euMatch.date)
            }
        case (let usMatch?, nil):
            return .parsed(date: usMatch.date, format: usMatch.format)
        case (nil, let euMatch?):
            return .parsed(date: euMatch.date, format: euMatch.format)
        case (nil, nil):
            return .failed
        }
    }

    // MARK: - Detection on a Sample

    /// Given a sample of date strings (first ~10 rows of a CSV column),
    /// detect the most likely format. Returns the format and how many
    /// of the sample parsed successfully with it.
    static func detectFormat(from samples: [String]) -> (format: Format, matchCount: Int)? {
        var bestFormat: Format?
        var bestCount = 0

        for format in Format.allCases {
            let count = samples.reduce(0) { partial, sample in
                tryFormat(format, on: sample.trimmingCharacters(in: .whitespacesAndNewlines)) != nil ? partial + 1 : partial
            }
            if count > bestCount {
                bestCount = count
                bestFormat = format
            }
        }

        guard let bestFormat, bestCount > 0 else { return nil }
        return (bestFormat, bestCount)
    }

    // MARK: - Helpers

    private static func tryFormat(_ format: Format, on string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format.rawValue
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        return formatter.date(from: string)
    }

    private static func tryFirstSuccess(formats: [Format], on string: String) -> (date: Date, format: Format)? {
        for format in formats {
            if let date = tryFormat(format, on: string) {
                return (date, format)
            }
        }
        return nil
    }
}
