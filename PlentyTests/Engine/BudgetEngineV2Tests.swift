//
//  BudgetEngineV2Tests.swift
//  PlentyTests
//
//  Target path: PlentyTests/Engine/BudgetEngineV2Tests.swift
//
//  Phase 1 (v2): unit tests for the new `monthlyBudgetRemaining`
//  field. Covers PDS §2.4 worked examples to the cent, plus edge
//  cases the formula's design decisions depend on.
//
//  Uses Swift Testing (Xcode 16+, iOS 17+). If your test target uses
//  XCTest instead, rename `@Test` → `func testXxx() throws`, drop
//  `import Testing`, and replace `#expect(...)` with
//  `XCTAssertEqual(...)`.
//
//  The tests construct unattached Transaction @Model instances and
//  pass them straight into BudgetEngine.calculate. No ModelContainer
//  required — calculate() is a pure function over arrays.
//

import Testing
import Foundation
@testable import Plenty

@MainActor
struct BudgetEngineV2Tests {

    // MARK: - Test month

    /// PDS §2.4 examples are framed in April 2026.
    static let targetMonth = 4
    static let targetYear = 2026

    // MARK: - PDS §2.4 Worked Examples

    @Test("Day 1: $0 confirmed, $2,100 bills, $0 expenses → -$2,100")
    func day1NewMonth_negativeHero() {
        let bills = Self.fivePDSBills()  // sums to $2,100
        let snapshot = BudgetEngine.calculate(
            accounts: [],
            transactions: bills,
            month: Self.targetMonth,
            year: Self.targetYear
        )

        #expect(snapshot.monthlyBudgetRemaining == Decimal(-2100))
        #expect(snapshot.confirmedIncomeThisMonth == 0)
        #expect(snapshot.billsThisMonth == Decimal(2100))
        #expect(snapshot.expensesThisMonth == 0)
    }

    @Test("Day 5: $2,400 confirmed, $2,100 bills, $0 expenses → $300")
    func day5_paycheckOneConfirmed() {
        var transactions = Self.fivePDSBills()
        transactions.append(.testConfirmedIncome(
            name: "Paycheck #1", amount: 2400, day: 5,
            month: Self.targetMonth, year: Self.targetYear
        ))

        let snapshot = BudgetEngine.calculate(
            accounts: [], transactions: transactions,
            month: Self.targetMonth, year: Self.targetYear
        )

        #expect(snapshot.monthlyBudgetRemaining == Decimal(300))
        #expect(snapshot.confirmedIncomeThisMonth == Decimal(2400))
    }

    @Test("Day 12: $2,400 confirmed, $2,100 bills, $180 expenses → $120")
    func day12_paidRentAndGroceries() {
        var transactions = Self.fivePDSBills()
        // Rent gets marked paid — should NOT change the math.
        if let rentIndex = transactions.firstIndex(where: { $0.name == "Rent" }) {
            transactions[rentIndex].isPaid = true
            transactions[rentIndex].paidAt = .now
        }
        transactions.append(.testConfirmedIncome(
            name: "Paycheck #1", amount: 2400, day: 5,
            month: Self.targetMonth, year: Self.targetYear
        ))
        transactions.append(.testExpense(
            name: "Groceries", amount: 180, day: 8,
            month: Self.targetMonth, year: Self.targetYear
        ))

        let snapshot = BudgetEngine.calculate(
            accounts: [], transactions: transactions,
            month: Self.targetMonth, year: Self.targetYear
        )

        #expect(snapshot.monthlyBudgetRemaining == Decimal(120))
        #expect(snapshot.expensesThisMonth == Decimal(180))
        #expect(snapshot.billsPaid == Decimal(1500))    // rent was paid
        #expect(snapshot.billsThisMonth == Decimal(2100)) // total unchanged
    }

    @Test("Day 19: $4,800 confirmed, $2,100 bills, $420 expenses → $2,280")
    func day19_paycheckTwoConfirmed() {
        var transactions = Self.fivePDSBills()
        transactions.append(.testConfirmedIncome(
            name: "Paycheck #1", amount: 2400, day: 5,
            month: Self.targetMonth, year: Self.targetYear
        ))
        transactions.append(.testConfirmedIncome(
            name: "Paycheck #2", amount: 2400, day: 19,
            month: Self.targetMonth, year: Self.targetYear
        ))
        transactions.append(.testExpense(
            name: "Groceries", amount: 180, day: 8,
            month: Self.targetMonth, year: Self.targetYear
        ))
        transactions.append(.testExpense(
            name: "Dining", amount: 240, day: 15,
            month: Self.targetMonth, year: Self.targetYear
        ))

        let snapshot = BudgetEngine.calculate(
            accounts: [], transactions: transactions,
            month: Self.targetMonth, year: Self.targetYear
        )

        #expect(snapshot.monthlyBudgetRemaining == Decimal(2280))
        #expect(snapshot.confirmedIncomeThisMonth == Decimal(4800))
        #expect(snapshot.expensesThisMonth == Decimal(420))
    }

    @Test("Day 30: $4,800 confirmed, $2,100 bills, $2,650 expenses → $50")
    func day30_endOfMonth() {
        var transactions = Self.fivePDSBills()
        transactions.append(.testConfirmedIncome(
            name: "Paycheck #1", amount: 2400, day: 5,
            month: Self.targetMonth, year: Self.targetYear
        ))
        transactions.append(.testConfirmedIncome(
            name: "Paycheck #2", amount: 2400, day: 19,
            month: Self.targetMonth, year: Self.targetYear
        ))
        transactions.append(contentsOf: [
            .testExpense(name: "Groceries", amount: 850, day: 8, month: Self.targetMonth, year: Self.targetYear),
            .testExpense(name: "Dining",    amount: 620, day: 15, month: Self.targetMonth, year: Self.targetYear),
            .testExpense(name: "Gas",       amount: 180, day: 20, month: Self.targetMonth, year: Self.targetYear),
            .testExpense(name: "Shopping",  amount: 1000, day: 25, month: Self.targetMonth, year: Self.targetYear),
        ])

        let snapshot = BudgetEngine.calculate(
            accounts: [], transactions: transactions,
            month: Self.targetMonth, year: Self.targetYear
        )

        #expect(snapshot.monthlyBudgetRemaining == Decimal(50))
        #expect(snapshot.expensesThisMonth == Decimal(2650))
    }

    // MARK: - Design Invariants

    @Test("Marking a bill paid does not change the budget number")
    func paidBillsCountSameAsUnpaid() {
        let unpaidOnly = [
            Transaction.testBill(
                name: "Rent", amount: 1500, dueDay: 1,
                month: Self.targetMonth, year: Self.targetYear, isPaid: false
            )
        ]
        let paidOnly = [
            Transaction.testBill(
                name: "Rent", amount: 1500, dueDay: 1,
                month: Self.targetMonth, year: Self.targetYear, isPaid: true
            )
        ]

        let snapshotUnpaid = BudgetEngine.calculate(
            accounts: [], transactions: unpaidOnly,
            month: Self.targetMonth, year: Self.targetYear
        )
        let snapshotPaid = BudgetEngine.calculate(
            accounts: [], transactions: paidOnly,
            month: Self.targetMonth, year: Self.targetYear
        )

        #expect(snapshotUnpaid.monthlyBudgetRemaining == snapshotPaid.monthlyBudgetRemaining)
        #expect(snapshotUnpaid.monthlyBudgetRemaining == Decimal(-1500))
    }

    @Test("Expected income does not contribute to budget remaining")
    func expectedIncomeNotCounted() {
        let confirmed = Transaction.testConfirmedIncome(
            name: "Paycheck #1", amount: 2400, day: 5,
            month: Self.targetMonth, year: Self.targetYear
        )
        let expected = Transaction.testExpectedIncome(
            name: "Paycheck #2", amount: 2400, day: 19,
            month: Self.targetMonth, year: Self.targetYear
        )

        let snapshot = BudgetEngine.calculate(
            accounts: [], transactions: [confirmed, expected],
            month: Self.targetMonth, year: Self.targetYear
        )

        #expect(snapshot.monthlyBudgetRemaining == Decimal(2400))
        #expect(snapshot.confirmedIncomeThisMonth == Decimal(2400))
        #expect(snapshot.expectedIncomeRemaining == Decimal(2400))
        #expect(snapshot.totalIncome == Decimal(4800))
    }

    @Test("Empty state: no transactions → 0 with empty zone")
    func emptyState() {
        let snapshot = BudgetEngine.calculate(
            accounts: [], transactions: [],
            month: Self.targetMonth, year: Self.targetYear
        )

        #expect(snapshot.monthlyBudgetRemaining == 0)
        #expect(snapshot.zone == .empty)
        #expect(snapshot.monthlyBudgetIsNegative == false)
    }

    @Test("Refund (negative-amount expense) reduces total expenses")
    func refundReducesExpenses() {
        let snapshot = BudgetEngine.calculate(
            accounts: [],
            transactions: [
                .testConfirmedIncome(
                    name: "Paycheck", amount: 1000, day: 1,
                    month: Self.targetMonth, year: Self.targetYear
                ),
                .testExpense(
                    name: "Shopping", amount: 200, day: 5,
                    month: Self.targetMonth, year: Self.targetYear
                ),
                // A refund logged as a negative-amount expense.
                .testExpense(
                    name: "Refund — Shopping", amount: -50, day: 10,
                    month: Self.targetMonth, year: Self.targetYear
                ),
            ],
            month: Self.targetMonth, year: Self.targetYear
        )

        // Expenses net = 200 − 50 = 150
        #expect(snapshot.expensesThisMonth == Decimal(150))
        // Hero = 1000 − 0 − 150 = 850
        #expect(snapshot.monthlyBudgetRemaining == Decimal(850))
    }

    @Test("Negative hero is correctly flagged via monthlyBudgetIsNegative")
    func negativeHeroFlag() {
        let snapshot = BudgetEngine.calculate(
            accounts: [],
            transactions: [
                .testBill(
                    name: "Rent", amount: 1500, dueDay: 1,
                    month: Self.targetMonth, year: Self.targetYear
                )
            ],
            month: Self.targetMonth, year: Self.targetYear
        )

        #expect(snapshot.monthlyBudgetRemaining == Decimal(-1500))
        #expect(snapshot.monthlyBudgetIsNegative == true)
    }

    @Test("Different-month transactions are filtered out")
    func priorMonthTransactionsExcluded() {
        let priorMonth = Self.targetMonth - 1
        let snapshot = BudgetEngine.calculate(
            accounts: [],
            transactions: [
                // Prior month: should be ignored entirely.
                .testConfirmedIncome(
                    name: "Old Paycheck", amount: 9999, day: 15,
                    month: priorMonth, year: Self.targetYear
                ),
                .testBill(
                    name: "Old Rent", amount: 1500, dueDay: 1,
                    month: priorMonth, year: Self.targetYear
                ),
                // Current month: should count.
                .testConfirmedIncome(
                    name: "Paycheck", amount: 1000, day: 5,
                    month: Self.targetMonth, year: Self.targetYear
                ),
            ],
            month: Self.targetMonth, year: Self.targetYear
        )

        #expect(snapshot.monthlyBudgetRemaining == Decimal(1000))
        #expect(snapshot.confirmedIncomeThisMonth == Decimal(1000))
    }

    // MARK: - Test Fixture: PDS §2.4 Bills

    /// The five bills from PDS §2.4 examples, summing to $2,100:
    ///   Rent $1,500 (day 1)
    ///   Internet $100 (day 5)
    ///   Phone $60 (day 10)
    ///   Utilities $240 (day 15)
    ///   Insurance $200 (day 20)
    static func fivePDSBills() -> [Transaction] {
        [
            .testBill(name: "Rent",      amount: 1500, dueDay: 1,  month: targetMonth, year: targetYear),
            .testBill(name: "Internet",  amount: 100,  dueDay: 5,  month: targetMonth, year: targetYear),
            .testBill(name: "Phone",     amount: 60,   dueDay: 10, month: targetMonth, year: targetYear),
            .testBill(name: "Utilities", amount: 240,  dueDay: 15, month: targetMonth, year: targetYear),
            .testBill(name: "Insurance", amount: 200,  dueDay: 20, month: targetMonth, year: targetYear),
        ]
    }
}

// MARK: - BurnRate.monthEndProjection Tests

@MainActor
struct BurnRateMonthEndProjectionTests {

    @Test("Returns nil before minimumDaysForSignal")
    func nilBeforeMinimumDays() {
        // Day 3 of any month, with non-trivial daily burn.
        let day3 = makeDate(year: 2026, month: 4, day: 3)

        let result = BurnRate.monthEndProjection(
            currentExpenses: 60,
            smoothedDailyBurn: 20,
            reference: day3
        )
        #expect(result == nil)
    }

    @Test("Returns nil when daily burn is below noise threshold")
    func nilWhenBurnBelowSignal() {
        let day15 = makeDate(year: 2026, month: 4, day: 15)
        let result = BurnRate.monthEndProjection(
            currentExpenses: 0,
            smoothedDailyBurn: 0.50,  // below default minimum of 1
            reference: day15
        )
        #expect(result == nil)
    }

    @Test("Linear projection on a 30-day month, day 15, $20/day")
    func projectsLinearly() {
        // April has 30 days. Day 15 → 15 days remaining.
        // Current expenses $300 + (20 × 15) = $600 projected.
        let day15 = makeDate(year: 2026, month: 4, day: 15)
        let result = BurnRate.monthEndProjection(
            currentExpenses: 300,
            smoothedDailyBurn: 20,
            reference: day15
        )
        #expect(result == Decimal(600))
    }

    @Test("Last day of the month projects to current expenses (zero remaining)")
    func lastDayNoFurtherProjection() {
        let day30 = makeDate(year: 2026, month: 4, day: 30)
        let result = BurnRate.monthEndProjection(
            currentExpenses: 1234,
            smoothedDailyBurn: 50,
            reference: day30
        )
        #expect(result == Decimal(1234))
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}

// MARK: - Test Helpers

private extension Transaction {

    static func testBill(
        name: String,
        amount: Decimal,
        dueDay: Int = 1,
        month: Int,
        year: Int,
        isPaid: Bool = false
    ) -> Transaction {
        let date = Calendar.current.date(
            from: DateComponents(year: year, month: month, day: dueDay)
        ) ?? .now

        let tx = Transaction(
            kind: .bill,
            name: name,
            amount: amount,
            date: date,
            month: month,
            year: year,
            dueDay: dueDay
        )
        if isPaid {
            tx.isPaid = true
            tx.paidAt = date
        }
        return tx
    }

    static func testExpense(
        name: String,
        amount: Decimal,
        day: Int = 1,
        month: Int,
        year: Int
    ) -> Transaction {
        let date = Calendar.current.date(
            from: DateComponents(year: year, month: month, day: day)
        ) ?? .now

        return Transaction(
            kind: .expense,
            name: name,
            amount: amount,
            date: date,
            month: month,
            year: year
        )
    }

    static func testConfirmedIncome(
        name: String,
        amount: Decimal,
        day: Int = 1,
        month: Int,
        year: Int
    ) -> Transaction {
        let date = Calendar.current.date(
            from: DateComponents(year: year, month: month, day: day)
        ) ?? .now

        let tx = Transaction(
            kind: .income,
            name: name,
            amount: amount,
            date: date,
            month: month,
            year: year,
            expectedAmount: amount,
            incomeStatus: .confirmed
        )
        tx.confirmedAmount = amount
        return tx
    }

    static func testExpectedIncome(
        name: String,
        amount: Decimal,
        day: Int = 1,
        month: Int,
        year: Int
    ) -> Transaction {
        let date = Calendar.current.date(
            from: DateComponents(year: year, month: month, day: day)
        ) ?? .now

        return Transaction(
            kind: .income,
            name: name,
            amount: amount,
            date: date,
            month: month,
            year: year,
            expectedAmount: amount,
            incomeStatus: .expected
        )
    }
}
