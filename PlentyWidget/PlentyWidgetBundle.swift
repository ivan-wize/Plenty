//
//  PlentyWidgetBundle.swift
//  Plenty
//
//  Target path: PlentyWidget/PlentyWidgetBundle.swift
//  Widget target: PlentyWidget extension
//
//  Phase 8 (v2): same widget kind string preserved
//  ("com.plenty.app.widget"), so user instances on home screens carry
//  through. Display name and description updated for v2 vocabulary.
//  Entry view router references the renamed Small/Medium widgets.
//
//  Five families supported:
//    • systemSmall          — Home screen small
//    • systemMedium         — Home screen medium
//    • accessoryCircular    — Lock screen circular
//    • accessoryRectangular — Lock screen rectangular
//    • accessoryInline      — Lock screen above the clock
//

import SwiftUI
import WidgetKit

@main
struct PlentyWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlentyWidget()
    }
}

// MARK: - Widget Definition

struct PlentyWidget: Widget {
    /// IMPORTANT: this kind string must NOT change. WidgetKit uses it
    /// for identity — changing it would orphan every user widget on
    /// every home screen. The Swift type names around it have changed
    /// (SmallSpendableWidget → SmallBudgetWidget etc.) but the kind
    /// stays.
    let kind = "com.plenty.app.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlentyTimelineProvider()) { entry in
            PlentyWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Budget")
        .description("See how much budget you have left this month, at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Entry View Router

struct PlentyWidgetEntryView: View {

    @Environment(\.widgetFamily) var family
    let entry: PlentyEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallBudgetWidget(entry: entry)
        case .systemMedium:
            MediumBudgetWidget(entry: entry)
        case .accessoryCircular:
            CircularLockScreenView(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenView(entry: entry)
        case .accessoryInline:
            InlineLockScreenView(entry: entry)
        default:
            SmallBudgetWidget(entry: entry)
        }
    }
}
