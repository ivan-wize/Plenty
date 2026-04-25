//
//  PlentyApp.swift
//  Plenty
//
//  Target path: Plenty/App/PlentyApp.swift
//
//  Application entry point. Wires:
//    • SwiftData ModelContainer via ModelContainerFactory (Phase 3)
//    • AppState as an @Observable environment object (Phase 1)
//    • CloudKitSyncMonitor as an @Observable environment object (Phase 3)
//    • AppearanceMode preferred color scheme via @AppStorage
//
//  Sync monitor starts on appear and surfaces sync errors through the
//  RootView banner (Phase 4 onward will render that banner). For Phase 3
//  DoD verification, watch the console: clean sync looks like
//  "CloudKit sync event completed" entries with no errors.
//

import SwiftUI
import SwiftData

@main
struct PlentyApp: App {

    @State private var appState = AppState()
    @State private var syncMonitor = CloudKitSyncMonitor()

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    private let container: ModelContainer

    // MARK: - Init

    init() {
        // Build the container once at launch. Three-tier fallback inside
        // the factory means this never throws; worst case we fall back
        // to in-memory storage and the user is shown a "sync disabled"
        // notice via onCloudKitDisabled.
        self.container = ModelContainerFactory.make()
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(syncMonitor)
                .preferredColorScheme(currentAppearance.colorScheme)
                .task {
                    syncMonitor.startMonitoring()

                    // If CloudKit failed to initialize at container time,
                    // mark the monitor as disabled so the UI knows not to
                    // expect sync events.
                    if !ModelContainerFactory.isCloudKitEnabled {
                        syncMonitor.markDisabled()
                    }
                }
        }
        .modelContainer(container)
    }

    // MARK: - Appearance

    private var currentAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }
}
