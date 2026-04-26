//
//  Transaction.swift
//  Plenty
//
//  Target path: Plenty/Models/Transaction.swift
//
//  The unified model for every movement of money. Four kinds:
//    • .expense   one-time spending
//    • .bill      recurring monthly obligation
//    • .income    money arriving (expected or confirmed)
//    • .transfer  between accounts (includes savings contributions)
//
//  Every transaction posts to at least one account (sourceAccount).
//  Transfers additionally post to a destinationAccount.
//
//  Amount is always stored as positive magnitude; sign derives from kind
//  at read time.
//
//  Port from Left with `isShared: Bool` added for the V1.1 sharing hook.
//  Dormant in V1.0.
//

import Foundation
import SwiftData

@Model
final class Transaction {

    // MARK: - Identity

    var id: UUID = UUID()

    /// Discriminator. Stored raw for CloudKit.
    var kindRaw: String = TransactionKind.expense.rawValue

    // MARK: - Core

    var name: String = ""

    /// Positive magnitude. Sign derives from kind.
    var amount: Decimal = 0

    /// Date the transaction occurred or is scheduled for.
    var date: Date = Date()

    /// Category. Raw string for CloudKit. Nil for transfers that don't
    /// fit any category.
    var categoryRaw: String?

    /// Free-form note.
    var note: String?

    // MARK: - Month Scope

    /// Target month (1-12). For bills and income this is the budget
    /// month, which may differ from date.month (a January paycheck
    /// counted toward the December budget). For expenses this matches
    /// date.month.
    var month: Int = 1
    var year: Int = 2025

    // MARK: - Accounts

    /// Account this moves money FROM. Nullified on account delete so
    /// historical transactions survive.
    @Relationship(deleteRule: .nullify)
    var sourceAccount: Account?

    /// Account this moves money TO. Used by income (landing account)
    /// and transfers (destination).
    @Relationship(deleteRule: .nullify)
    var destinationAccount: Account?

    // MARK: - Bill Fields

    /// Day of month this bill is due. Populated only for kind == .bill.
    var dueDay: Int = 1

    /// Whether a bill has been paid.
    var isPaid: Bool = false

    /// When the bill was marked paid.
    var paidAt: Date?

    /// JSON-encoded RecurringRule. Populated for recurring bills and
    /// template-generated income entries.
    var recurringRuleData: String?

    /// For bills copied from a previous month: the source transaction's ID.
    /// Nil for the first occurrence or for manually-added bills.
    var copiedFromID: UUID?

    // MARK: - Income Fields

    /// Original expected amount before confirmation. Preserved even when
    /// the user confirms a different actual amount.
    var expectedAmount: Decimal = 0

    /// Confirmed actual amount, once the user confirms the income arrived.
    /// Nil for expected or skipped entries.
    var confirmedAmount: Decimal?

    /// Income status. Raw string for CloudKit.
    var incomeStatusRaw: String = IncomeStatus.expected.rawValue

    /// The IncomeSource template this entry was generated from, if any.
    @Relationship(deleteRule: .nullify)
    var incomeSource: IncomeSource?

    /// Stable dedupe key: "sourceID:yyyy-MM-dd". Prevents IncomeEntryGenerator
    /// from creating duplicates across local and CloudKit paths.
    var dedupeKey: String?

    // MARK: - Transfer Fields

    /// Savings goal this transfer contributes to. Nil if the transfer isn't
    /// a savings contribution.
    @Relationship(deleteRule: .nullify)
    var savingsGoal: SavingsGoal?

    // MARK: - Receipt

    /// Receipt image data, stored inline. Nil if no receipt.
    @Attribute(.externalStorage)
    var receiptImageData: Data?

    // MARK: - Sharing (V1.1 hook)

    /// Reserved for V1.1 household sharing. Dormant in V1.0.
    var isShared: Bool = false

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Init

    init(
        kind: TransactionKind,
        name: String,
        amount: Decimal,
        date: Date = .now,
        category: TransactionCategory? = nil,
        note: String? = nil,
        month: Int? = nil,
        year: Int? = nil,
        sourceAccount: Account? = nil,
        destinationAccount: Account? = nil,
        dueDay: Int = 1,
        recurringRule: RecurringRule? = nil,
        expectedAmount: Decimal = 0,
        incomeStatus: IncomeStatus = .expected,
        incomeSource: IncomeSource? = nil,
        savingsGoal: SavingsGoal? = nil,
        receiptImageData: Data? = nil
    ) {
        let cal = Calendar.current
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.name = name
        self.amount = amount
        self.date = date
        self.categoryRaw = category?.rawValue
        self.note = note
        self.month = month ?? cal.component(.month, from: date)
        self.year = year ?? cal.component(.year, from: date)
        self.sourceAccount = sourceAccount
        self.destinationAccount = destinationAccount
        self.dueDay = dueDay
        self.isPaid = false
        self.recurringRuleData = recurringRule?.encoded()
        self.expectedAmount = expectedAmount
        self.confirmedAmount = nil
        self.incomeStatusRaw = incomeStatus.rawValue
        self.incomeSource = incomeSource
        self.savingsGoal = savingsGoal
        self.receiptImageData = receiptImageData
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Computed

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var category: TransactionCategory? {
        get {
            guard let categoryRaw else { return nil }
            return TransactionCategory(rawValue: categoryRaw)
        }
        set { categoryRaw = newValue?.rawValue }
    }

    var incomeStatus: IncomeStatus {
        get { IncomeStatus(rawValue: incomeStatusRaw) ?? .expected }
        set { incomeStatusRaw = newValue.rawValue }
    }

    var recurringRule: RecurringRule? {
        get { RecurringRule.decode(from: recurringRuleData) }
        set { recurringRuleData = newValue?.encoded() }
    }

    /// True for entries that can still be acted on by the user.
    var isActionable: Bool {
        switch kind {
        case .income: return incomeStatus == .expected
        case .bill:   return !isPaid
        default:      return true
        }
    }

    // MARK: - Actions

    func markPaid(at date: Date = .now) {
        guard kind == .bill else { return }
        isPaid = true
        paidAt = date
        touch()
    }

    func markUnpaid() {
        guard kind == .bill else { return }
        isPaid = false
        paidAt = nil
        touch()
    }

    func confirmIncome(actualAmount: Decimal) {
        guard kind == .income else { return }
        confirmedAmount = actualAmount
        incomeStatus = .confirmed
        amount = actualAmount
        touch()
    }

    func skipIncome() {
        guard kind == .income else { return }
        confirmedAmount = nil
        incomeStatus = .skipped
        touch()
    }

    func revertIncome() {
        guard kind == .income else { return }
        confirmedAmount = nil
        incomeStatus = .expected
        amount = expectedAmount
        touch()
    }

    private func touch() { updatedAt = .now }

    // MARK: - Factory Helpers

    static func expense(
        name: String,
        amount: Decimal,
        date: Date = .now,
        category: TransactionCategory? = nil,
        sourceAccount: Account? = nil,
        receiptImageData: Data? = nil
    ) -> Transaction {
        Transaction(
            kind: .expense,
            name: name,
            amount: amount,
            date: date,
            category: category,
            sourceAccount: sourceAccount,
            receiptImageData: receiptImageData
        )
    }

    static func bill(
        name: String,
        amount: Decimal,
        dueDay: Int,
        month: Int,
        year: Int,
        category: TransactionCategory? = nil,
        sourceAccount: Account? = nil,
        recurringRule: RecurringRule? = nil
    ) -> Transaction {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = dueDay
        let dueDate = Calendar.current.date(from: comps) ?? .now
        return Transaction(
            kind: .bill,
            name: name,
            amount: amount,
            date: dueDate,
            category: category,
            month: month,
            year: year,
            sourceAccount: sourceAccount,
            dueDay: dueDay,
            recurringRule: recurringRule ?? .monthly(onDay: dueDay, startingFrom: dueDate)
        )
    }

    static func manualIncome(
        name: String,
        amount: Decimal,
        date: Date = .now,
        category: TransactionCategory? = .paycheck,
        destinationAccount: Account? = nil
    ) -> Transaction {
        let tx = Transaction(
            kind: .income,
            name: name,
            amount: amount,
            date: date,
            category: category,
            destinationAccount: destinationAccount,
            expectedAmount: amount,
            incomeStatus: .confirmed
        )
        tx.confirmedAmount = amount
        return tx
    }

    static func expectedIncome(
        name: String,
        expectedAmount: Decimal,
        date: Date,
        source: IncomeSource,
        destinationAccount: Account? = nil
    ) -> Transaction {
        let cal = Calendar.current
        let tx = Transaction(
            kind: .income,
            name: name,
            amount: expectedAmount,
            date: date,
            category: .paycheck,
            destinationAccount: destinationAccount,
            expectedAmount: expectedAmount,
            incomeStatus: .expected,
            incomeSource: source
        )
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        tx.dedupeKey = "\(source.id.uuidString):\(y)-\(String(format: "%02d", m))-\(String(format: "%02d", d))"
        return tx
    }

    static func transfer(
        name: String,
        amount: Decimal,
        date: Date = .now,
        from source: Account,
        to destination: Account,
        category: TransactionCategory? = nil,
        savingsGoal: SavingsGoal? = nil
    ) -> Transaction {
        let inferredCategory = category ?? inferTransferCategory(from: source, to: destination)
        return Transaction(
            kind: .transfer,
            name: name,
            amount: amount,
            date: date,
            category: inferredCategory,
            sourceAccount: source,
            destinationAccount: destination,
            savingsGoal: savingsGoal
        )
    }

    private static func inferTransferCategory(from source: Account, to destination: Account) -> TransactionCategory {
        switch destination.kind {
        case .credit:     return .creditCardPayment
        case .loan:       return .loanPayment
        case .investment: return .investmentContribution
        case .cash:       return .savingsTransfer
        }
    }

    func copiedAsBill(toMonth targetMonth: Int, year targetYear: Int) -> Transaction {
        let copy = Transaction.bill(
            name: name,
            amount: amount,
            dueDay: dueDay,
            month: targetMonth,
            year: targetYear,
            category: category,
            sourceAccount: sourceAccount,
            recurringRule: recurringRule
        )
        copy.note = note
        copy.copiedFromID = id
        return copy
    }
}

// MARK: - Income Status

enum IncomeStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case expected
    case confirmed
    case skipped

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expected:  return "Expected"
        case .confirmed: return "Confirmed"
        case .skipped:   return "Skipped"
        }
    }
}
