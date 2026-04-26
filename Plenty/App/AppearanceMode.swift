//
//  AppearanceMode.swift
//  Plenty
//
//  Target path: Plenty/App/AppearanceMode.swift
//
//  The user's color-scheme preference. Surfaced in Settings > Appearance
//  per PRD §9.17. Persisted as a raw string in UserDefaults under
//  `AppearanceMode.storageKey`.
//
//  The rawValue is stable and kept short because it ends up in a plist.
//  Don't change the raw strings once the app has shipped.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    // MARK: - Storage

    /// Stable UserDefaults key. Referenced from PlentyApp via @AppStorage.
    static let storageKey = "appearanceMode"

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    // MARK: - SwiftUI Bridging

    /// The SwiftUI color scheme to apply. `nil` for `.system` means
    /// "let the OS decide," which is what `preferredColorScheme` expects.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
