//
//  SubscriptionReminderManager.swift
//  Plenty
//
//  Target path: Plenty/Notifications/SubscriptionReminderManager.swift
//
//  Creates calendar events for subscription cancellations the user has
//  marked. EventKit is intentional — the user wanted these to show up
//  next to their other commitments and persist across app deletions.
//
//  When a subscription's isMarkedToCancel flips on:
//    1. Request EventKit authorization (if not already granted)
//    2. Find the user's default calendar
//    3. Create an all-day event 3 days before next charge date
//    4. Title: "Cancel <merchant>"
//    5. Notes: "Plenty reminder. Last day to cancel before next charge."
//
//  When isMarkedToCancel flips off, the event is removed.
//

import Foundation
import EventKit
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "subscriptions")

@Observable
@MainActor
final class SubscriptionReminderManager {

    private let eventStore = EKEventStore()
    private static let plentyEventNotePrefix = "Plenty reminder."

    // MARK: - Authorization

    /// Request full access to events. iOS 17+ split read/write; we need write.
    /// Returns true on grant.
    func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess:
            return true
        case .writeOnly:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                logger.error("EventKit access request failed: \(error.localizedDescription)")
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Schedule

    /// Create a calendar event 3 days before next charge for a marked
    /// subscription. Returns true on success.
    @discardableResult
    func scheduleReminder(for subscription: Subscription) async -> Bool {
        let granted = await requestAccess()
        guard granted else { return false }

        guard let nextCharge = subscription.nextChargeDate else {
            logger.warning("Cannot schedule reminder for \(subscription.merchantName) — no next charge date.")
            return false
        }

        let cal = Calendar.current
        guard let reminderDate = cal.date(byAdding: .day, value: -3, to: nextCharge) else { return false }

        // Don't schedule for past dates.
        guard reminderDate > .now else { return false }

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            logger.warning("No default calendar for new events.")
            return false
        }

        // Remove any existing Plenty reminder for this subscription first.
        await removeReminder(for: subscription)

        let event = EKEvent(eventStore: eventStore)
        event.title = "Cancel \(subscription.merchantName)"
        event.notes = "\(Self.plentyEventNotePrefix) Last day to cancel \(subscription.merchantName) before the next charge of \(subscription.monthlyCost.asPlainCurrency())."
        event.startDate = reminderDate
        event.endDate = reminderDate
        event.isAllDay = true
        event.calendar = calendar

        // Tag with subscription ID for later lookup.
        event.url = URL(string: "plenty://subscription/\(subscription.id.uuidString)")

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return true
        } catch {
            logger.error("Failed to save reminder event: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Remove

    /// Remove the calendar event Plenty created for this subscription.
    /// Searches by URL tag in the next 60 days.
    func removeReminder(for subscription: Subscription) async {
        let granted = await requestAccess()
        guard granted else { return }

        let cal = Calendar.current
        let now = Date.now
        guard let endDate = cal.date(byAdding: .day, value: 60, to: now) else { return }

        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        let tagURL = URL(string: "plenty://subscription/\(subscription.id.uuidString)")

        for event in events where event.url == tagURL {
            do {
                try eventStore.remove(event, span: .thisEvent, commit: false)
            } catch {
                logger.error("Failed to remove event: \(error.localizedDescription)")
            }
        }

        do {
            try eventStore.commit()
        } catch {
            logger.error("Failed to commit event removals: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync All

    /// Reconcile all marked subscriptions to their reminder state. Call
    /// after subscription mark-to-cancel toggles change or on app launch.
    func syncReminders(for subscriptions: [Subscription]) async {
        for sub in subscriptions where sub.state == .confirmed {
            if sub.isMarkedToCancel, sub.nextChargeDate != nil {
                await scheduleReminder(for: sub)
            } else {
                await removeReminder(for: sub)
            }
        }
    }
}

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
