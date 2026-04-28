//
//  TheRead.swift
//  Plenty
//
//  Target path: Plenty/Features/Home/TheRead/TheRead.swift
//
//  Phase 4: six kinds (silence, paceWarning, paceTrend, billReminder,
//           incomeReminder, milestone). One sentence each.
//  Phase 7: + .weekly case for the Sunday Read. Body is up to 3 sentences,
//           sent as a notification body Sunday mornings.
//
//  Pure value type. Generation lives in TheReadEngine. Display lives
//  in TheReadView (daily kinds). Notification delivery lives in
//  NotificationScheduler (weekly kind).
//

import Foundation

struct TheRead: Equatable, Sendable {

    // MARK: - Type

    enum Kind: String, Codable, CaseIterable, Sendable {
        case silence
        case paceWarning
        case paceTrend
        case billReminder
        case incomeReminder
        case milestone

        // Phase 7
        /// "Sunday Read" — weekly digest delivered as a notification.
        /// Body is 1-3 sentences. Generated weekly, not daily.
        case weekly

        var displayName: String {
            switch self {
            case .silence:        return "Silence"
            case .paceWarning:    return "Pace Warning"
            case .paceTrend:      return "Pace Trend"
            case .billReminder:   return "Bill Reminder"
            case .incomeReminder: return "Income Reminder"
            case .milestone:      return "Milestone"
            case .weekly:         return "Sunday Read"
            }
        }

        /// Whether this kind is shown inline on Home (daily) or
        /// delivered as a notification (weekly).
        var deliveryChannel: DeliveryChannel {
            self == .weekly ? .notification : .inline
        }

        enum DeliveryChannel { case inline, notification }
    }

    // MARK: - Properties

    let kind: Kind
    let body: String
    let generatedAt: Date
    let isAIGenerated: Bool

    // MARK: - Display

    var shouldDisplay: Bool {
        kind != .silence && !body.isEmpty && kind.deliveryChannel == .inline
    }

    // MARK: - Constants

    static let silence = TheRead(
        kind: .silence,
        body: "",
        generatedAt: .now,
        isAIGenerated: false
    )
}
