//
//  CSVImportSession.swift
//  Plenty
//
//  Target path: Plenty/Import/CSVImportSession.swift
//
//  In-memory model for an import in progress. Held by ImportCSVSheet
//  and passed down through the flow (column mapping → preview →
//  commit). Not persisted; lives only for the duration of the import.
//
//  Holds the raw file, parsed rows, current column mapping, current
//  date format, target account, candidate transactions with dedupe
//  markers, and per-row inclusion flags.
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class CSVImportSession {

    // MARK: - Stage

    enum Stage: Sendable {
        case picking
        case mapping
        case preview
        case importing
        case complete(imported: Int, skipped: Int)
        case failed(String)
    }

    var stage: Stage = .picking

    // MARK: - Raw

    var fileName: String = ""
    var parsedFile: CSVParser.ParsedFile?

    // MARK: - Mapping

    var mapping: CSVColumnDetector.Mapping?
    var dateFormat: CSVDateParser.Format?
    var targetAccount: Account?

    // MARK: - Candidates

    var candidates: [Candidate] = []

    /// Single parsed row — what the user reviews in the preview screen.
    struct Candidate: Identifiable, Sendable {
        let id = UUID()
        var name: String
        var amount: Decimal
        var date: Date
        var kind: TransactionKind
        var category: TransactionCategory?
        var dedupeStatus: DedupeStatus
        var include: Bool       // user can deselect rows in preview
        var rawLineIndex: Int
        var parseError: String?
    }

    enum DedupeStatus: Sendable, Equatable {
        case unique
        case exactDuplicate(of: UUID)        // an existing Transaction's id
        case nearMatch(of: UUID, reason: String)
    }

    // MARK: - Computed

    var includedCount: Int {
        candidates.filter(\.include).count
    }

    var excludedCount: Int {
        candidates.count - includedCount
    }

    var dedupeCount: Int {
        candidates.filter { c in
            if case .exactDuplicate = c.dedupeStatus { return true }
            return false
        }.count
    }

    var nearMatchCount: Int {
        candidates.filter { c in
            if case .nearMatch = c.dedupeStatus { return true }
            return false
        }.count
    }

    var errorCount: Int {
        candidates.filter { $0.parseError != nil }.count
    }

    // MARK: - Build Candidates

    /// Apply current mapping + dateFormat to parsed rows, producing
    /// candidates. Called when the user advances from mapping to preview.
    func buildCandidates(against existingTransactions: [Transaction]) {
        guard let parsedFile, let mapping else {
            candidates = []
            return
        }

        var built: [Candidate] = []

        for (rowIndex, row) in parsedFile.rows.enumerated() {
            let candidate = parseCandidate(row: row, rowIndex: rowIndex, mapping: mapping)
            built.append(candidate)
        }

        // Dedupe pass against existing data.
        for index in built.indices {
            built[index].dedupeStatus = computeDedupeStatus(
                candidate: built[index],
                existing: existingTransactions
            )
            // Auto-deselect exact duplicates by default.
            if case .exactDuplicate = built[index].dedupeStatus {
                built[index].include = false
            }
        }

        candidates = built
    }

    // MARK: - Parse a Single Row

    private func parseCandidate(
        row: [String],
        rowIndex: Int,
        mapping: CSVColumnDetector.Mapping
    ) -> Candidate {
        // Date
        let dateString = row.indices.contains(mapping.dateColumn) ? row[mapping.dateColumn] : ""
        let dateResult = CSVDateParser.parse(dateString, preferredFormat: dateFormat)
        let parsedDate: Date?
        switch dateResult {
        case .parsed(let d, _): parsedDate = d
        case .ambiguous(let us, _): parsedDate = us  // Will be flagged via parseError
        case .failed: parsedDate = nil
        }

        // Description
        let description = row.indices.contains(mapping.descriptionColumn)
            ? row[mapping.descriptionColumn].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        // Amount + sign
        let (amount, kind) = parseAmount(row: row, convention: mapping.signConvention)

        // Category auto-detect (rule-based, fast)
        let category: TransactionCategory? = {
            guard !description.isEmpty else { return nil }
            let detected = ExpenseCategorizer.detect(from: description)
            return detected == .other ? nil : detected
        }()

        var error: String?
        if parsedDate == nil { error = "Couldn't parse date." }
        if amount == 0 { error = (error.map { $0 + " " } ?? "") + "Couldn't parse amount." }
        if description.isEmpty { error = (error.map { $0 + " " } ?? "") + "Description is empty." }

        if case .ambiguous = dateResult {
            error = (error.map { $0 + " " } ?? "") + "Ambiguous date format. Pick US or EU above."
        }

        return Candidate(
            name: description.isEmpty ? "Imported Transaction" : description,
            amount: amount,
            date: parsedDate ?? .now,
            kind: kind,
            category: category,
            dedupeStatus: .unique,
            include: error == nil,
            rawLineIndex: rowIndex + 2,  // +2 because index 0 is row 1, header is row 1
            parseError: error
        )
    }

    private func parseAmount(
        row: [String],
        convention: CSVColumnDetector.SignConvention
    ) -> (Decimal, TransactionKind) {
        switch convention {
        case .signedAmount(let column):
            let raw = row.indices.contains(column) ? row[column] : ""
            let cleaned = cleanAmountString(raw)
            guard let value = Decimal(string: cleaned) else { return (0, .expense) }
            if value < 0 {
                return (-value, .expense)
            } else {
                return (value, .income)
            }

        case .debitCreditSplit(let debitColumn, let creditColumn):
            let debitRaw = row.indices.contains(debitColumn) ? row[debitColumn] : ""
            let creditRaw = row.indices.contains(creditColumn) ? row[creditColumn] : ""
            let debit = Decimal(string: cleanAmountString(debitRaw)) ?? 0
            let credit = Decimal(string: cleanAmountString(creditRaw)) ?? 0
            if debit > 0 {
                return (debit, .expense)
            } else if credit > 0 {
                return (credit, .income)
            }
            return (0, .expense)

        case .amountPlusIndicator(let amountColumn, let indicatorColumn):
            let amountRaw = row.indices.contains(amountColumn) ? row[amountColumn] : ""
            let amount = Decimal(string: cleanAmountString(amountRaw)) ?? 0
            let indicator = (row.indices.contains(indicatorColumn) ? row[indicatorColumn] : "")
                .uppercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let isCredit = indicator == "CR" || indicator == "CREDIT" || indicator == "+"
            return (amount, isCredit ? .income : .expense)
        }
    }

    private func cleanAmountString(_ raw: String) -> String {
        raw.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Dedupe

    private func computeDedupeStatus(
        candidate: Candidate,
        existing: [Transaction]
    ) -> DedupeStatus {
        let cal = Calendar.current
        let normalizedName = candidate.name.lowercased()

        for tx in existing {
            let sameDay = cal.isDate(tx.date, inSameDayAs: candidate.date)
            let sameAmount = tx.amount == candidate.amount
            let normalizedExisting = tx.name.lowercased()

            if sameDay && sameAmount && normalizedExisting == normalizedName {
                return .exactDuplicate(of: tx.id)
            }
            if sameDay && sameAmount {
                return .nearMatch(of: tx.id, reason: "Same date and amount, different description.")
            }
        }
        return .unique
    }

    // MARK: - Commit

    /// Insert all included candidates as new Transactions in modelContext.
    /// Returns count of imported and skipped rows.
    func commit(modelContext: ModelContext) -> (imported: Int, skipped: Int) {
        let included = candidates.filter(\.include)
        var imported = 0

        for candidate in included {
            let tx: Transaction
            switch candidate.kind {
            case .income:
                tx = Transaction.manualIncome(
                    name: candidate.name,
                    amount: candidate.amount,
                    date: candidate.date,
                    category: candidate.category ?? .paycheck,
                    destinationAccount: targetAccount
                )
            case .expense:
                tx = Transaction.expense(
                    name: candidate.name,
                    amount: candidate.amount,
                    date: candidate.date,
                    category: candidate.category,
                    sourceAccount: targetAccount
                )
            case .bill, .transfer:
                // Imported transactions are always treated as expense
                // or income — bill recurrence and transfer routing
                // are not inferable from CSV.
                tx = Transaction.expense(
                    name: candidate.name,
                    amount: candidate.amount,
                    date: candidate.date,
                    category: candidate.category,
                    sourceAccount: targetAccount
                )
            }

            modelContext.insert(tx)
            imported += 1
        }

        do {
            try modelContext.save()
        } catch {
            return (0, candidates.count)
        }

        return (imported, candidates.count - imported)
    }

    // MARK: - Reset

    func reset() {
        stage = .picking
        fileName = ""
        parsedFile = nil
        mapping = nil
        dateFormat = nil
        targetAccount = nil
        candidates = []
    }
}
