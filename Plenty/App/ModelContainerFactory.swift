//
//  ModelContainerFactory.swift
//  Plenty
//
//  Target path: Plenty/App/ModelContainerFactory.swift
//
//  Creates the SwiftData ModelContainer for the main app, intents, and
//  the watch. Three-tier fallback so the app always launches:
//
//    1. CloudKit-backed persistent store         (primary)
//    2. Local-only persistent store              (CloudKit init failed)
//    3. In-memory store                          (disk unavailable)
//
//  The CloudKit container identifier comes from entitlements
//  (`com.apple.developer.icloud-container-identifiers`), set in Phase 1
//  to `iCloud.com.plenty.app`. SwiftData picks it up automatically when
//  `cloudKitDatabase: .automatic`.
//
//  Uses SwiftData's default store location. A custom App Group URL
//  breaks CloudKit's zone mapping; the App Group is reserved for
//  shared UserDefaults and other intent/widget coordination.
//

import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "container")

enum ModelContainerFactory {

    // MARK: - Identifiers

    /// App Group identifier. Used for shared UserDefaults and other
    /// intent/widget coordination, NOT for the SwiftData store.
    static let appGroupID = "group.com.plenty.app"

    // MARK: - Schema

    /// Every @Model type registered with the container. Keep in sync
    /// with files in Plenty/Models/. New @Model types must be added
    /// here BEFORE first launch, or SwiftData won't recognize them.
    static let allModels: [any PersistentModel.Type] = [
        Account.self,
        AccountBalance.self,
        Transaction.self,
        IncomeSource.self,
        SavingsGoal.self,
        SpendingLimit.self,
        Subscription.self,        // NEW in Plenty
    ]

    // MARK: - State

    /// Whether the container was created with CloudKit enabled.
    /// false means the app fell back to local-only or in-memory storage.
    @MainActor
    private(set) static var isCloudKitEnabled = false

    /// Callback invoked when CloudKit initialization fails and the app
    /// falls back to local-only storage. Set by the main app target so
    /// the user can be notified that iCloud isn't syncing.
    @MainActor
    static var onCloudKitDisabled: (() -> Void)?

    // MARK: - Main App Container

    /// The container used by the main app target. Three-tier fallback.
    @MainActor
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(allModels)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            cloudKitDatabase: inMemory ? .none : .automatic
        )

        // Tier 1: CloudKit-backed (or in-memory if explicitly requested).
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            isCloudKitEnabled = !inMemory
            logger.info("ModelContainer created with CloudKit \(inMemory ? "disabled (in-memory)" : "enabled")")
            return container
        } catch {
            logger.error("CloudKit container failed: \(error.localizedDescription)")
            onCloudKitDisabled?()
        }

        // Tier 2: Local-only persistent store.
        do {
            let localOnly = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [localOnly])
            isCloudKitEnabled = false
            logger.warning("Running with local-only storage. iCloud sync is DISABLED.")
            return container
        } catch {
            logger.error("Local-only container failed: \(error.localizedDescription)")
        }

        // Tier 3: In-memory store. Last resort so the app at least launches.
        do {
            let memory = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [memory])
            isCloudKitEnabled = false
            logger.critical("Running in-memory. Data will not persist across launches.")
            return container
        } catch {
            logger.fault("Unrecoverable SwiftData error: \(error.localizedDescription)")
            fatalError("Plenty: Unrecoverable SwiftData error: \(error)")
        }
    }

    // MARK: - Intent / Extension Container

    /// Container for App Intents, widgets, and other extensions that need
    /// to read user data outside the main app process. Returns nil if
    /// the container can't be created (intent should fail gracefully).
    @MainActor
    static func makeForIntent() -> ModelContainer? {
        let schema = Schema(allModels)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.error("Intent container failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Watch Container

    /// Container for the Plenty Watch app. Same fallback chain as main
    /// but logged separately so watch sync issues are easy to spot.
    @MainActor
    static func makeForWatch() -> ModelContainer {
        let schema = Schema(allModels)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            logger.info("[Plenty Watch] ModelContainer created with CloudKit enabled")
            return container
        } catch {
            logger.error("[Plenty Watch] CloudKit container failed: \(error.localizedDescription)")
        }

        do {
            let localOnly = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [localOnly])
            logger.warning("[Plenty Watch] Running with local-only storage")
            return container
        } catch {
            logger.error("[Plenty Watch] Local-only container failed: \(error.localizedDescription)")
        }

        do {
            let memory = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [memory])
            logger.critical("[Plenty Watch] Running in-memory. Data will not persist.")
            return container
        } catch {
            logger.fault("[Plenty Watch] Unrecoverable SwiftData error: \(error.localizedDescription)")
            fatalError("[Plenty Watch] Unrecoverable SwiftData error: \(error)")
        }
    }
}
