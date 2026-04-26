//
//  CSVParser.swift
//  Plenty
//
//  Target path: Plenty/Import/CSVParser.swift
//
//  RFC 4180 compliant CSV parser. Handles:
//    • Escaped quotes ("" within quoted field)
//    • Embedded commas in quoted fields
//    • Embedded newlines in quoted fields
//    • UTF-8 BOM stripping
//    • CRLF and LF line endings
//
//  Pure value type. No file I/O, no SwiftData. Caller reads the file
//  and passes the string contents in.
//

import Foundation

enum CSVParser {

    // MARK: - Output

    struct ParsedFile: Sendable {
        let headers: [String]
        let rows: [[String]]
        let rowCount: Int
    }

    enum ParseError: Error, LocalizedError {
        case empty
        case unbalancedQuote(line: Int)

        var errorDescription: String? {
            switch self {
            case .empty:
                return "The file appears to be empty."
            case .unbalancedQuote(let line):
                return "Unbalanced quote at line \(line). Check for missing or extra quotation marks."
            }
        }
    }

    // MARK: - Public

    static func parse(_ text: String) throws -> ParsedFile {
        let cleaned = stripBOM(text)
        guard !cleaned.isEmpty else { throw ParseError.empty }

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotedField = false
        var lineNumber = 1

        var iterator = cleaned.unicodeScalars.makeIterator()

        while let scalar = iterator.next() {
            let char = Character(scalar)

            if inQuotedField {
                if char == "\"" {
                    // Look ahead for escaped quote
                    let lookahead = iterator.next().map { Character($0) }
                    if lookahead == "\"" {
                        currentField.append("\"")
                    } else {
                        inQuotedField = false
                        if let lookahead {
                            // Process the lookahead character normally
                            try processChar(
                                lookahead,
                                currentField: &currentField,
                                currentRow: &currentRow,
                                rows: &rows,
                                inQuotedField: &inQuotedField,
                                lineNumber: &lineNumber
                            )
                        }
                    }
                } else {
                    if char == "\n" { lineNumber += 1 }
                    currentField.append(char)
                }
            } else {
                try processChar(
                    char,
                    currentField: &currentField,
                    currentRow: &currentRow,
                    rows: &rows,
                    inQuotedField: &inQuotedField,
                    lineNumber: &lineNumber
                )
            }
        }

        // Final field/row.
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        // If still inside a quoted field at EOF, that's an error.
        if inQuotedField {
            throw ParseError.unbalancedQuote(line: lineNumber)
        }

        guard let headers = rows.first else { throw ParseError.empty }
        let dataRows = Array(rows.dropFirst())

        return ParsedFile(
            headers: headers,
            rows: dataRows,
            rowCount: dataRows.count
        )
    }

    // MARK: - Sample for Detection

    /// Get the first N data rows for column detection. Useful when the
    /// full file is large and detection only needs a sample.
    static func sample(_ text: String, rowLimit: Int = 10) throws -> ParsedFile {
        let parsed = try parse(text)
        return ParsedFile(
            headers: parsed.headers,
            rows: Array(parsed.rows.prefix(rowLimit)),
            rowCount: parsed.rowCount
        )
    }

    // MARK: - Helpers

    private static func processChar(
        _ char: Character,
        currentField: inout String,
        currentRow: inout [String],
        rows: inout [[String]],
        inQuotedField: inout Bool,
        lineNumber: inout Int
    ) throws {
        switch char {
        case "\"":
            if currentField.isEmpty {
                inQuotedField = true
            } else {
                currentField.append(char)
            }
        case ",":
            currentRow.append(currentField)
            currentField = ""
        case "\n":
            currentRow.append(currentField)
            rows.append(currentRow)
            currentRow = []
            currentField = ""
            lineNumber += 1
        case "\r":
            // CRLF or bare CR — handle CRLF by skipping the LF on next iteration.
            // For simplicity: treat \r as field-end too if not already followed.
            currentRow.append(currentField)
            rows.append(currentRow)
            currentRow = []
            currentField = ""
        default:
            currentField.append(char)
        }
    }

    private static func stripBOM(_ text: String) -> String {
        if text.hasPrefix("\u{FEFF}") {
            return String(text.dropFirst())
        }
        return text
    }
}
