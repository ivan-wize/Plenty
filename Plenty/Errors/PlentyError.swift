//
//  PlentyError.swift
//  Plenty
//
//  Target path: Plenty/Errors/PlentyError.swift
//
//  Phase 4.2 (post-launch v1): converted user-facing strings to
//  `String(localized:)` so they extract into Localizable.xcstrings
//  on build.
//
//  Pattern:
//
//    return String(
//      localized: "Couldn't save",
//      comment: "PlentyError.saveFailed title shown on the error banner."
//    )
//
//  String interpolation works inside the `localized:` literal — Xcode
//  preserves the format specifier (e.g. `%@`) and translators see the
//  literal with placeholder hints.
//
//  ----- Earlier history -----
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
            return String(
                localized: "Sync paused",
                comment: "PlentyError.cloudKitSyncFailed title shown on the error banner."
            )
        case .saveFailed:
            return String(
                localized: "Couldn't save",
                comment: "PlentyError.saveFailed title shown on the error banner."
            )
        case .aiUnavailable:
            return String(
                localized: "Smart features unavailable",
                comment: "PlentyError.aiUnavailable title shown on the error banner."
            )
        case .importFailed:
            return String(
                localized: "Import failed",
                comment: "PlentyError.importFailed title shown on the error banner."
            )
        case .calendarAccessDenied:
            return String(
                localized: "Calendar access needed",
                comment: "PlentyError.calendarAccessDenied title shown on the error banner."
            )
        case .generic:
            return String(
                localized: "Something went wrong",
                comment: "PlentyError.generic title shown on the error banner."
            )
        }
    }

    var detail: String {
        switch self {
        case .cloudKitSyncFailed(let message):
            // The interpolated `message` is system-provided (e.g. CloudKit
            // error description). Translators see "%@" with the comment
            // explaining what fills it.
            return String(
                localized: "Plenty couldn't reach iCloud. Your data is safe on this device. \(message)",
                comment: "PlentyError.cloudKitSyncFailed detail. Trailing %@ is the system error description."
            )
        case .saveFailed(let message):
            return String(
                localized: "Plenty couldn't write your last change. \(message)",
                comment: "PlentyError.saveFailed detail. Trailing %@ is the system error description."
            )
        case .aiUnavailable:
            return String(
                localized: "Apple Intelligence isn't available right now. Plenty will use simpler text in the meantime.",
                comment: "PlentyError.aiUnavailable detail."
            )
        case .importFailed(let message):
            // The message is the user-facing description from the import
            // pipeline (already localized at its source). Pass through.
            return message
        case .calendarAccessDenied:
            return String(
                localized: "Plenty needs calendar access to schedule cancellation reminders. Enable it in iOS Settings.",
                comment: "PlentyError.calendarAccessDenied detail."
            )
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
