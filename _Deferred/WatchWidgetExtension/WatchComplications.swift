//
//  WatchComplications.swift
//  Plenty
//
//  Target path: PlentyWatch/WatchComplications.swift
//
//  Watch face complications. Two families:
//    • accessoryCircular    — single number on a corner
//    • accessoryRectangular — number + brief context strip
//
//  Reuses PlentyTimelineProvider (same data path as iPhone widgets)
//  and reuses the lock screen views verbatim — those layouts work
//  identically on watch face complications.
//
//  This file declares the watchOS-side WidgetBundle. The shared
//  provider and entry types come from the widget extension and must
//  also be linked into the watch widget extension target.
//

import SwiftUI
import WidgetKit

// MARK: - Bundle

@main
struct PlentyWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlentyWatchComplication()
    }
}

// MARK: - Widget Definition

struct PlentyWatchComplication: Widget {
    let kind = "com.plenty.app.watch.complication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlentyTimelineProvider()) { entry in
            PlentyWatchComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spendable")
        .description("See your spendable on your watch face.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Entry View Router

struct PlentyWatchComplicationView: View {

    @Environment(\.widgetFamily) var family
    let entry: PlentyEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularLockScreenView(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenView(entry: entry)
        case .accessoryInline:
            InlineLockScreenView(entry: entry)
        default:
            CircularLockScreenView(entry: entry)
        }
    }
}
