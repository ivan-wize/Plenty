//
//  NotificationsSection.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/NotificationsSection.swift
//
//  Settings section for notification toggles. Each toggle requests
//  authorization on first enable; reverts to off if denied. Bill
//  reminder timing picker (morning/night) shown when bill reminders
//  are enabled.
//

import SwiftUI

struct NotificationsSection: View {

    @Environment(NotificationManager.self) private var notifications

    @State private var weeklyRead: Bool = false
    @State private var billReminders: Bool = false
    @State private var subscriptionReminders: Bool = false
    @State private var nightBefore: Bool = false

    @State private var showingDeniedAlert = false

    var body: some View {
        Section {
            Toggle("Sunday Read", isOn: $weeklyRead)
                .onChange(of: weeklyRead) { _, newValue in
                    Task { await applyWeeklyRead(newValue) }
                }

            Toggle("Bill Reminders", isOn: $billReminders)
                .onChange(of: billReminders) { _, newValue in
                    Task { await applyBillReminders(newValue) }
                }

            if billReminders {
                Picker("When", selection: $nightBefore) {
                    Text("Morning of").tag(false)
                    Text("Night before").tag(true)
                }
                .pickerStyle(.menu)
                .onChange(of: nightBefore) { _, newValue in
                    notifications.billReminderNightBefore = newValue
                }
            }

            Toggle("Subscription Cancellation Calendar Events", isOn: $subscriptionReminders)
                .onChange(of: subscriptionReminders) { _, newValue in
                    Task { await applySubscriptionReminders(newValue) }
                }
        } header: {
            Text("Notifications")
        } footer: {
            Text(footerText)
                .font(Typography.Support.caption)
        }
        .onAppear { syncFromManager() }
        .alert("Notifications Disabled", isPresented: $showingDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Plenty needs notification permission. Enable it in iOS Settings to turn this on.")
        }
    }

    // MARK: - Sync

    private func syncFromManager() {
        weeklyRead = notifications.weeklyReadEnabled
        billReminders = notifications.billRemindersEnabled
        subscriptionReminders = notifications.subscriptionRemindersEnabled
        nightBefore = notifications.billReminderNightBefore
    }

    // MARK: - Toggle Handlers

    @MainActor
    private func applyWeeklyRead(_ enabled: Bool) async {
        let success = await notifications.setWeeklyReadEnabled(enabled)
        if !success && enabled {
            // Authorization denied. Revert UI and prompt to Settings.
            weeklyRead = false
            showingDeniedAlert = true
        }
    }

    @MainActor
    private func applyBillReminders(_ enabled: Bool) async {
        let success = await notifications.setBillRemindersEnabled(enabled)
        if !success && enabled {
            billReminders = false
            showingDeniedAlert = true
        }
    }

    @MainActor
    private func applySubscriptionReminders(_ enabled: Bool) async {
        let success = await notifications.setSubscriptionRemindersEnabled(enabled)
        if !success && enabled {
            subscriptionReminders = false
        }
    }

    // MARK: - Footer

    private var footerText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Plenty schedules notifications locally. Nothing leaves your device."
        case .denied:
            return "Notifications are denied in iOS Settings. Open Settings to enable."
        case .notDetermined:
            return "Plenty schedules notifications locally. Nothing leaves your device. You'll be asked for permission when you turn one on."
        @unknown default:
            return ""
        }
    }
}
