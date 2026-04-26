//
//  PlentyWatchApp.swift
//  Plenty
//
//  Target path: PlentyWatch/PlentyWatchApp.swift
//  Watch target: PlentyWatch (watchOS 26+)
//
//  Entry point for the Plenty Watch companion. Syncs with iPhone via
//  CloudKit through the shared App Group. No WatchConnectivity
//  required — eventual consistency through CloudKit is sub-minute and
//  perfectly adequate for budgeting.
//
//  Required configuration:
//    • Watch target signed with the same App Group as iPhone
//      (group.com.plenty.app)
//    • Watch target signed with the same CloudKit container
//      (iCloud.com.plenty.app)
//    • Watch target's Info.plist has WKApplication = YES (modern
//      single-target watch app, not WatchKit Extension)
//

import SwiftUI
import SwiftData

@main
struct PlentyWatchApp: App {

    let container: ModelContainer

    init() {
        // makeForWatch() returns the same configuration as the iPhone
        // app: SwiftData with CloudKit private database, App Group
        // storage path. Falls back to local-only if CloudKit fails.
        self.container = ModelContainerFactory.makeForWatch()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
        .modelContainer(container)
    }
}
