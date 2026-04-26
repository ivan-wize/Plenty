//
//  PlentyError.swift
//  Plenty
//
//  Target path: Plenty/Errors/PlentyError.swift
//
//  Unified user-facing error type. Most error paths in the app
//  log-and-continue silently, which is fine for non-blocking issues
//  (a failed background sync attempt, a one-off AI generation
//  failure). PlentyError is reserved for failures the user needs to
//  know about and can act on:
//
//    • CloudKit sync errors that persist
//    • Save failures during user-initiated actions
//    • AI generation failures that affected the displayed content
//    • Import failures
//    • EventKit access denials
//
//  Set on AppState.lastError; rendered by ErrorBanner. The banner
//  is dismissible by the user and auto-clears on next app launch.
//

import Foundation

enum PlentyError: Error, Identifiable, Equatable, Sendable {

    case cloudKitSyncFailed(String)
    case saveFailed(String)
    case aiUnavailable
    case importFailed(String)
    case calendarAccessDenied
    case generic(String)

    var id: String {
        switch self {
        case .cloudKitSyncFailed:    return "cloudKitSyncFailed"
        case .saveFailed:            return "saveFailed"
        case .aiUnavailable:         return "aiUnavailable"
        case .importFailed:          return "importFailed"
        case .calendarAccessDenied:  return "calendarAccessDenied"
        case .generic:               return "generic"
        }
    }

    // MARK: - Display

    var title: String {
        switch self {
        case .cloudKitSyncFailed:
            return "Sync paused"
        case .saveFailed:
            return "Couldn't save"
        case .aiUnavailable:
            return "Smart features unavailable"
        case .importFailed:
            return "Import failed"
        case .calendarAccessDenied:
            return "Calendar access needed"
        case .generic:
            return "Something went wrong"
        }
    }

    var detail: String {
        switch self {
        case .cloudKitSyncFailed(let message):
            return "Plenty couldn't reach iCloud. Your data is safe on this device. \(message)"
        case .saveFailed(let message):
            return "Plenty couldn't write your last change. \(message)"
        case .aiUnavailable:
            return "Apple Intelligence isn't available right now. Plenty will use simpler text in the meantime."
        case .importFailed(let message):
            return message
        case .calendarAccessDenied:
            return "Plenty needs calendar access to schedule cancellation reminders. Enable it in iOS Settings."
        case .generic(let message):
            return message
        }
    }

    /// Whether the error banner has an "Open Settings" action.
    var offersSettingsLink: Bool {
        switch self {
        case .calendarAccessDenied:
            return true
        default:
            return false
        }
    }

    /// Severity drives the banner's color (amber for soft, terracotta for hard).
    enum Severity: Sendable { case soft, hard }

    var severity: Severity {
        switch self {
        case .aiUnavailable, .cloudKitSyncFailed:
            return .soft
        default:
            return .hard
        }
    }
}
