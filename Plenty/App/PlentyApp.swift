//
//  PlentyApp.swift
//  Plenty
//
//  Target path: Plenty/App/PlentyApp.swift
//
//  Application entry point. Wires every @Observable manager that
//  RootView and its descendants depend on into the SwiftUI environment:
//
//    • AppState                     — selected tab, pending sheets, errors
//    • CloudKitSyncMonitor          — background sync status
//    • StoreKitManager              — Pro purchase state
//    • NotificationManager          — auth + per-channel toggles
//    • SubscriptionReminderManager  — EventKit-based cancel reminders
//
//  Construction order: each manager is built by SwiftUI when the
//  property initializers run. AppState wiring happens in `.task` after
//  the View tree exists, since the @State properties can't reference
//  one another in their initializers.
//

import SwiftUI
import SwiftData

@main
struct PlentyApp: App {

    // MARK: - Managers

    @State private var appState = AppState()
    @State private var syncMonitor = CloudKitSyncMonitor()
    @State private var storeKit = StoreKitManager()
    @State private var notifications = NotificationManager()
    @State private var subscriptionReminders = SubscriptionReminderManager()

    @State private var showOnboarding = false

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    private let container: ModelContainer

    // MARK: - Init

    init() {
        // Build the container once at launch. Three-tier fallback inside
        // the factory means this never throws; worst case we fall back
        // to in-memory storage and the user is shown a "sync disabled"
        // notice via the sync monitor.
        self.container = ModelContainerFactory.make()
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(syncMonitor)
                .environment(storeKit)
                .environment(notifications)
                .environment(subscriptionReminders)
                .preferredColorScheme(currentAppearance.colorScheme)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView()
                }
                .onAppear {
                    showOnboarding = OnboardingView.shouldShow
                }
                .task {
                    // Cross-wire managers that need a reference to AppState.
                    // Done here (not in init) because @State property
                    // initializers can't reference one another.
                    storeKit.attach(appState: appState)
                    syncMonitor.attach(appState: appState)

                    syncMonitor.start()

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
