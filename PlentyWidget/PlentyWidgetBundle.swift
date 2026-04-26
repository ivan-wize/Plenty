//
//  PlentyWidgetBundle.swift
//  Plenty
//
//  Target path: PlentyWidget/PlentyWidgetBundle.swift
//  Widget target: PlentyWidget extension
//
//  Bundle entry point. Declares the single Plenty widget and routes
//  to the right view based on widgetFamily.
//
//  Five families supported:
//    • systemSmall          — Home screen small
//    • systemMedium         — Home screen medium
//    • accessoryCircular    — Lock screen circular
//    • accessoryRectangular — Lock screen rectangular
//    • accessoryInline      — Lock screen above the clock
//
//  Skipped: systemLarge (real estate not earned by the content),
//  systemExtraLarge (iPad only, not v1 priority).
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
    let kind = "com.plenty.app.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlentyTimelineProvider()) { entry in
            PlentyWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spendable")
        .description("See how much you have to spend this month, at a glance.")
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
            SmallSpendableWidget(entry: entry)
        case .systemMedium:
            MediumSpendableWidget(entry: entry)
        case .accessoryCircular:
            CircularLockScreenView(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenView(entry: entry)
        case .accessoryInline:
            InlineLockScreenView(entry: entry)
        default:
            SmallSpendableWidget(entry: entry)
        }
    }
}
