//
//  NotificationManager.swift
//  Plenty
//
//  Target path: Plenty/Notifications/NotificationManager.swift
//
//  Owns notification authorization and per-channel preference toggles.
//  Per Left's policy carried forward into Plenty:
//
//    "Never request authorization on cold launch — gate it behind a
//     user-initiated Settings toggle."
//
//  Three channels, each with its own UserDefaults toggle:
//    • weeklyReadEnabled       — Sunday Read notification
//    • billRemindersEnabled    — bill due-day reminders
//    • subscriptionRemindersEnabled — subscription cancellation prompts
//                                      (delivered via EventKit, see
//                                      SubscriptionReminderManager)
//
//  Each toggle, when flipped on, requests authorization if not already
//  granted. If denied, the toggle reverts and the user is shown the
//  path to Settings.
//

import Foundation
import UserNotifications
import os
import Observation

private let logger = Logger(subsystem: "com.plenty.app", category: "notifications")

@Observable
@MainActor
final class NotificationManager {

    // MARK: - UserDefaults Keys

    private static let weeklyReadKey = "plenty.notifications.weeklyRead"
    private static let billRemindersKey = "plenty.notifications.billReminders"
    private static let subscriptionRemindersKey = "plenty.notifications.subscriptionReminders"
    private static let billReminderTimingKey = "plenty.notifications.billReminderTiming"

    // MARK: - State

    /// System-level authorization status. Updated by refreshAuthorizationStatus().
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Per-channel toggles. Backed by UserDefaults so they persist.

    var weeklyReadEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.weeklyReadKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.weeklyReadKey)
        }
    }

    var billRemindersEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.billRemindersKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.billRemindersKey)
        }
    }

    var subscriptionRemindersEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.subscriptionRemindersKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.subscriptionRemindersKey)
        }
    }

    /// Whether bill reminders fire morning-of (false) or night-before (true).
    var billReminderNightBefore: Bool {
        get { UserDefaults.standard.bool(forKey: Self.billReminderTimingKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.billReminderTimingKey) }
    }

    // MARK: - Lifecycle

    init() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Authorization

    /// Refresh the cached system authorization status. Called on launch
    /// and after the user returns from system Settings.
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    /// Request notification authorization. Returns true on grant.
    /// Called when a Settings toggle flips on for the first time.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                await refreshAuthorizationStatus()
                return granted
            } catch {
                logger.error("Notification authorization request failed: \(error.localizedDescription)")
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Toggle Wrappers

    /// Set weekly Read enabled. Returns true if successfully enabled
    /// (or disabled). Caller should revert UI on false.
    @discardableResult
    func setWeeklyReadEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let granted = await requestAuthorizationIfNeeded()
            if !granted { return false }
        }
        weeklyReadEnabled = enabled
        return true
    }

    @discardableResult
    func setBillRemindersEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let granted = await requestAuthorizationIfNeeded()
            if !granted { return false }
        }
        billRemindersEnabled = enabled
        return true
    }

    @discardableResult
    func setSubscriptionRemindersEnabled(_ enabled: Bool) async -> Bool {
        // Subscription reminders use EventKit, not UNNotifications.
        // Authorization handled by SubscriptionReminderManager.
        subscriptionRemindersEnabled = enabled
        return true
    }
}
