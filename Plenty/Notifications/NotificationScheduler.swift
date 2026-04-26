//
//  NotificationScheduler.swift
//  Plenty
//
//  Target path: Plenty/Notifications/NotificationScheduler.swift
//
//  Schedules actual notifications based on NotificationManager toggle
//  state and current SwiftData. Idempotent — clears its own pending
//  notifications and rebuilds from scratch each call. Safe to run on
//  app launch and after data changes.
//
//  Identifier prefixes for management:
//    plenty.notif.weekly         — single recurring weekly Read
//    plenty.notif.bill.<uuid>    — one per upcoming bill (max 30 days out)
//
//  Subscription reminders are handled by SubscriptionReminderManager
//  (EventKit), not here.
//

import Foundation
import UserNotifications
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "notifications")

@MainActor
struct NotificationScheduler {

    let manager: NotificationManager
    let modelContext: ModelContext

    // MARK: - Identifier Prefixes

    private static let weeklyIdentifier = "plenty.notif.weekly"
    private static let billIdentifierPrefix = "plenty.notif.bill."

    // MARK: - Public Entry

    /// Reschedule all enabled notifications. Call on app launch and
    /// whenever bill or income data changes meaningfully.
    func rescheduleAll(snapshot: PlentySnapshot, weeklyRead: TheRead?) async {
        // Always clear our own pending; rebuild from current state.
        await clearOurPending()

        if manager.weeklyReadEnabled, manager.authorizationStatus == .authorized {
            await scheduleWeeklyRead(weeklyRead)
        }

        if manager.billRemindersEnabled, manager.authorizationStatus == .authorized {
            await scheduleBillReminders()
        }
    }

    // MARK: - Weekly Read

    private func scheduleWeeklyRead(_ read: TheRead?) async {
        let body: String
        if let read, !read.body.isEmpty {
            body = read.body
        } else {
            body = "A calm look at where you stand this week."
        }

        let content = UNMutableNotificationContent()
        content.title = "Sunday Read"
        content.body = body
        content.sound = .default
        content.threadIdentifier = "plenty.weekly"

        // Sunday at 9am.
        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.weeklyIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to schedule weekly Read: \(error.localizedDescription)")
        }
    }

    // MARK: - Bill Reminders

    private func scheduleBillReminders() async {
        // Look 30 days ahead. One reminder per unpaid bill in that window.
        let cal = Calendar.current
        let now = Date.now
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)

        guard let allTransactions = try? modelContext.fetch(FetchDescriptor<Transaction>()) else {
            return
        }

        let unpaidThisMonth = TransactionProjections.bills(allTransactions, month: m, year: y)
            .filter { !$0.isPaid }

        // Also next month's bills for the last week of current month.
        let nextMonthDate = cal.date(byAdding: .month, value: 1, to: now)!
        let nm = cal.component(.month, from: nextMonthDate)
        let ny = cal.component(.year, from: nextMonthDate)

        // Project next month's bills from existing recurring rules. Use
        // existing transactions with .recurringRule, generating a
        // virtual due date for next month.
        let recurringBills = allTransactions.filter { $0.kind == .bill && $0.recurringRule != nil }
        let nextMonthBills = recurringBills.compactMap { tx -> ScheduledBill? in
            guard let rule = tx.recurringRule, rule.occursIn(month: nm, year: ny) else { return nil }
            var comps = DateComponents()
            comps.year = ny
            comps.month = nm
            comps.day = tx.dueDay
            guard let date = cal.date(from: comps) else { return nil }
            return ScheduledBill(name: tx.name, amount: tx.amount, dueDate: date, transactionID: tx.id)
        }

        let currentMonthBills = unpaidThisMonth.compactMap { tx -> ScheduledBill? in
            var comps = DateComponents()
            comps.year = y
            comps.month = m
            comps.day = tx.dueDay
            guard let date = cal.date(from: comps) else { return nil }
            // Skip overdue — no point scheduling a notification for the past.
            guard date >= cal.startOfDay(for: now) else { return nil }
            return ScheduledBill(name: tx.name, amount: tx.amount, dueDate: date, transactionID: tx.id)
        }

        let allBills = (currentMonthBills + nextMonthBills)
            .filter { $0.dueDate <= cal.date(byAdding: .day, value: 30, to: now)! }

        for bill in allBills {
            await scheduleSingleBillReminder(bill: bill)
        }
    }

    private func scheduleSingleBillReminder(bill: ScheduledBill) async {
        let cal = Calendar.current
        let triggerDate: Date
        if manager.billReminderNightBefore {
            // 8pm the night before due date.
            guard let dayBefore = cal.date(byAdding: .day, value: -1, to: bill.dueDate) else { return }
            triggerDate = cal.date(bySettingHour: 20, minute: 0, second: 0, of: dayBefore) ?? dayBefore
        } else {
            // 9am morning of due date.
            triggerDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: bill.dueDate) ?? bill.dueDate
        }

        // Don't schedule if the trigger time has passed.
        guard triggerDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = bill.name
        content.body = manager.billReminderNightBefore
            ? "Due tomorrow. \(bill.amount.asPlainCurrency())."
            : "Due today. \(bill.amount.asPlainCurrency())."
        content.sound = .default
        content.threadIdentifier = "plenty.bills"

        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "\(Self.billIdentifierPrefix)\(bill.transactionID.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to schedule bill reminder for \(bill.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    /// Remove all pending notifications scheduled by Plenty. Other apps'
    /// notifications are not touched.
    private func clearOurPending() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let plentyIDs = pending
            .map(\.identifier)
            .filter { $0 == Self.weeklyIdentifier || $0.hasPrefix(Self.billIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: plentyIDs)
    }

    // MARK: - Helper Type

    private struct ScheduledBill {
        let name: String
        let amount: Decimal
        let dueDate: Date
        let transactionID: UUID
    }
}

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
