//
//  CloudKitSyncMonitor.swift
//  Plenty
//
//  Target path: Plenty/App/CloudKitSyncMonitor.swift
//
//  Observes NSPersistentCloudKitContainer event notifications. On
//  persistent sync failure (multiple consecutive failures), surfaces
//  the error via AppState.lastError so ErrorBanner displays it.
//
//  Counts consecutive failures. Single transient failures are ignored
//  — CloudKit retries on its own and sync usually recovers. Three
//  consecutive failures (over ~5 minutes) is treated as a real outage
//  worth surfacing.
//
//  All event handling stays on the MainActor. The notification streams
//  are consumed from `Task { @MainActor }` so the @MainActor methods
//  on this class can be called without `await`.
//

import Foundation
import SwiftData
import CoreData
import os
import Observation

private let logger = Logger(subsystem: "com.plenty.app", category: "cloudkit-sync")

@Observable
@MainActor
final class CloudKitSyncMonitor {

    // MARK: - State

    enum SyncStatus: Equatable, Sendable {
        case unknown
        case syncing
        case succeeded
        case failed(String)
        case disabled
    }

    private(set) var status: SyncStatus = .unknown
    private(set) var lastSyncDate: Date?
    private(set) var consecutiveFailures: Int = 0

    /// Threshold above which the monitor surfaces an error to AppState.
    /// Three failures over ~5 minutes is treated as a real outage.
    private static let failureThreshold = 3

    private weak var appState: AppState?

    private var remoteChangeTask: Task<Void, Never>?
    private var cloudKitEventTask: Task<Void, Never>?

    // MARK: - Init

    init(appState: AppState? = nil) {
        self.appState = appState
    }

    func attach(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Lifecycle

    func start() {
        stop()

        // Both tasks are tagged @MainActor so the call to
        // self?.handleRemoteChange() / handleCloudKitEvent() lands on
        // the actor without an extra hop. The notifications AsyncSequence
        // is itself isolated-friendly.
        remoteChangeTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: .NSPersistentStoreRemoteChange
            ) {
                self?.handleRemoteChange()
            }
        }

        cloudKitEventTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: NSPersistentCloudKitContainer.eventChangedNotification
            ) {
                self?.handleCloudKitEvent(notification)
            }
        }

        logger.info("CloudKit sync monitoring started")
    }

    func stop() {
        remoteChangeTask?.cancel()
        cloudKitEventTask?.cancel()
        remoteChangeTask = nil
        cloudKitEventTask = nil
    }

    // MARK: - State Transitions

    func markDisabled() {
        status = .disabled
        logger.warning("CloudKit sync disabled. Running with local-only storage.")
    }

    // MARK: - Event Handling

    private func handleRemoteChange() {
        status = .succeeded
        lastSyncDate = .now
        consecutiveFailures = 0

        // If we previously surfaced a sync error, clear it on success.
        if case .cloudKitSyncFailed = appState?.lastError {
            appState?.lastError = nil
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        let event = (notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                  ?? notification.userInfo?["event"]) as? NSPersistentCloudKitContainer.Event
        guard let event else {
            logger.fault("CloudKit event notification missing payload.")
            return
        }

        if event.endDate == nil {
            status = .syncing
            return
        }

        if event.succeeded {
            handleRemoteChange()
        } else {
            consecutiveFailures += 1
            let message = event.error?.localizedDescription ?? "Unknown sync error."
            status = .failed(message)

            logger.error("CloudKit sync failure (\(self.consecutiveFailures) consecutive): \(message)")

            if consecutiveFailures >= Self.failureThreshold {
                appState?.lastError = .cloudKitSyncFailed(message)
            }
        }
    }
}
