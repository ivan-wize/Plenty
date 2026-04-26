//
//  DemoModeService.swift
//  Plenty
//
//  Target path: Plenty/Services/DemoModeService.swift
//
//  Seeds and clears realistic demo data so a new user can explore
//  every screen without entering any of their own information first.
//
//  Per PRD §16 acceptance #7: "A user can tap Start with demo data,
//  explore every major feature against realistic data, and return to
//  an empty app state via Start fresh."
//
//  The seed creates a credible household:
//    • Two cash accounts (Chase Checking, Apple Savings)
//    • One credit card (Apple Card) with a recent statement balance
//    • One investment account (401k)
//    • A biweekly paycheck (~$2,400 take-home)
//    • Six recurring monthly bills covering housing, utilities, etc.
//    • Two months of past expenses spread across categories
//    • One savings goal (Vacation, partially funded)
//    • Two confirmed subscriptions (streaming + cloud storage)
//
//  The "demo mode is active" flag is stored in shared UserDefaults
//  under the App Group so the widget and watch can render a banner
//  too, and is the only signal needed to display DemoModeBanner.
//

import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "demo-mode")

@MainActor
enum DemoModeService {

    // MARK: - Active Flag

    private static let demoActiveKey = "plenty.demoMode.active"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: ModelContainerFactory.appGroupID) ?? .standard
    }

    /// Whether the user has seeded demo data and not yet cleared it.
    /// Read by DemoModeBanner to decide whether to display, and by
    /// onboarding to suppress duplicate seeding.
    static var isActive: Bool {
        get { sharedDefaults.bool(forKey: demoActiveKey) }
        set { sharedDefaults.set(newValue, forKey: demoActiveKey) }
    }

    // MARK: - Seed

    /// Insert the demo dataset into the given context. Idempotent only
    /// in the sense that calling it twice will produce duplicates —
    /// callers should ensure isActive is false first, or call
    /// clearAll(modelContext:) before re-seeding.
    static func seed(modelContext: ModelContext) {
        let cal = Calendar.current
        let now = Date.now

        // ---------- Accounts ----------
        let checking = Account(
            name: "Chase Checking",
            category: .debit,
            balance: 2_840
        )
        let savings = Account(
            name: "Apple Savings",
            category: .savings,
            balance: 6_400
        )
        let card = Account(
            name: "Apple Card",
            category: .creditCard,
            balance: 1_180,
            interestRate: 19.99,
            minimumPayment: 35,
            creditLimitOrOriginalBalance: 5_000,
            statementDay: 23,
            statementBalance: 1_180
        )
        let retirement = Account(
            name: "Vanguard 401k",
            category: .investment,
            balance: 48_200
        )
        for account in [checking, savings, card, retirement] {
            modelContext.insert(account)
        }

        // ---------- Income source ----------
        // Biweekly paycheck anchored two Fridays back so this month's
        // pay dates are realistic.
        let twoFridaysAgo = cal.date(byAdding: .day, value: -14, to: lastFriday(before: now, calendar: cal)) ?? now
        let paycheck = IncomeSource(
            name: "Paycheck",
            expectedAmount: 2_400,
            frequency: .biweekly,
            weekday: 6,                       // Friday
            biweeklyAnchor: twoFridaysAgo,
            isActive: true
        )
        modelContext.insert(paycheck)

        // ---------- Recurring bills ----------
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)

        let bills: [(String, Decimal, Int, TransactionCategory, Account)] = [
            ("Rent",            1_650, 1,  .housing,       checking),
            ("Internet",        65,    5,  .utilities,     checking),
            ("Phone",           80,    8,  .utilities,     checking),
            ("Electric",        110,   12, .utilities,     checking),
            ("Renters Insurance", 22,  15, .housing,       checking),
            ("Gym",             45,    20, .health,        card),
        ]
        for (name, amount, day, category, source) in bills {
            let bill = Transaction.bill(
                name: name,
                amount: amount,
                dueDay: day,
                month: m,
                year: y,
                category: category,
                sourceAccount: source,
                recurringRule: .monthly(onDay: day, startingFrom: now)
            )
            // Mark the first two as already paid so the Home glance has
            // a realistic mix.
            if name == "Rent" || name == "Internet" {
                bill.markPaid()
            }
            modelContext.insert(bill)
        }

        // ---------- Past expenses (this month + last) ----------
        let expenses: [(String, Decimal, Int, TransactionCategory, Account)] = [
            ("Trader Joe's",    87.42,  -2,  .groceries,      checking),
            ("Blue Bottle",     6.50,   -2,  .dining,         card),
            ("Shell",           42.10,  -3,  .transportation, card),
            ("Whole Foods",     112.85, -5,  .groceries,      checking),
            ("CVS",             18.40,  -6,  .health,         card),
            ("Target",          54.22,  -7,  .shopping,       card),
            ("Sweetgreen",      14.95,  -8,  .dining,         card),
            ("Uber",            22.50,  -9,  .transportation, card),
            ("Amazon",          39.99,  -11, .shopping,       card),
            ("Trader Joe's",    72.18,  -14, .groceries,      checking),
            ("Coffee shop",     5.25,   -15, .dining,         card),
            ("Movie tickets",   34.00,  -18, .entertainment,  card),
        ]
        for (name, amount, daysAgo, category, source) in expenses {
            guard let date = cal.date(byAdding: .day, value: daysAgo, to: now) else { continue }
            let tx = Transaction.expense(
                name: name,
                amount: amount,
                date: date,
                category: category,
                sourceAccount: source
            )
            modelContext.insert(tx)
        }

        // ---------- Savings goal ----------
        let vacation = SavingsGoal(
            name: "Vacation",
            targetAmount: 3_000,
            goalType: .vacation,
            deadline: cal.date(byAdding: .month, value: 8, to: now),
            monthlyContribution: 200,
            note: "Trip to Lisbon next summer",
            emoji: "✈️"
        )
        modelContext.insert(vacation)

        // Two prior contributions toward the vacation goal.
        for monthsAgo in 1...2 {
            guard let date = cal.date(byAdding: .month, value: -monthsAgo, to: now) else { continue }
            let tx = Transaction.savingsContribution(
                name: "Vacation",
                amount: 200,
                date: date,
                goal: vacation
            )
            modelContext.insert(tx)
        }

        // ---------- Subscriptions ----------
        let netflix = Subscription(
            merchantName: "Netflix",
            rawMerchantPattern: "netflix",
            typicalAmount: 15.49,
            cadence: .monthly,
            nextChargeDate: cal.date(byAdding: .day, value: 12, to: now),
            lastChargeDate: cal.date(byAdding: .day, value: -18, to: now),
            state: .confirmed
        )
        let icloud = Subscription(
            merchantName: "iCloud+",
            rawMerchantPattern: "icloud",
            typicalAmount: 2.99,
            cadence: .monthly,
            nextChargeDate: cal.date(byAdding: .day, value: 5, to: now),
            lastChargeDate: cal.date(byAdding: .day, value: -25, to: now),
            state: .confirmed
        )
        modelContext.insert(netflix)
        modelContext.insert(icloud)

        // ---------- Save and mark active ----------
        do {
            try modelContext.save()
            isActive = true
            logger.info("Demo dataset seeded successfully.")
        } catch {
            logger.error("Failed to seed demo data: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear

    /// Delete every record in every model and clear the active flag.
    /// Used both by the user's "Start fresh" action and by the safety
    /// path before re-seeding.
    static func clearAll(modelContext: ModelContext) {
        let modelTypes: [any PersistentModel.Type] = [
            Transaction.self,
            AccountBalance.self,
            Account.self,
            IncomeSource.self,
            SavingsGoal.self,
            SpendingLimit.self,
            Subscription.self,
        ]

        for type in modelTypes {
            do {
                try modelContext.delete(model: type)
            } catch {
                logger.error("Failed to delete \(String(describing: type)): \(error.localizedDescription)")
            }
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to commit demo clear: \(error.localizedDescription)")
        }

        isActive = false
        logger.info("Demo data cleared.")
    }

    // MARK: - Helpers

    private static func lastFriday(before date: Date, calendar: Calendar) -> Date {
        // weekday: Sunday = 1, Friday = 6
        let weekday = calendar.component(.weekday, from: date)
        let offset = (weekday + 1) % 7  // days back to most recent Friday
        return calendar.date(byAdding: .day, value: -offset, to: date) ?? date
    }
}
