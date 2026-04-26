//
//  AppearanceSection.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/AppearanceSection.swift
//
//  The Appearance section of the Settings tab. Binds to the AppearanceMode
//  @AppStorage from Phase 1. Fully functional from Phase 2.
//
//  PRD §9.17 lists "material intensity for Liquid Glass" alongside the
//  color-scheme picker, but that's a P10 polish item once there's enough
//  glass on screen to calibrate against. Phase 2 ships the color scheme
//  only.
//

import SwiftUI

struct AppearanceSection: View {

    @AppStorage(AppearanceMode.storageKey) private var raw = AppearanceMode.system.rawValue

    var body: some View {
        Section {
            Picker("Color scheme", selection: $raw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .sensoryFeedback(.selection, trigger: raw)
        } header: {
            Text("Appearance")
        } footer: {
            Text("System follows your device setting.")
                .font(Typography.Support.caption)
        }
    }
}

#Preview {
    Form {
        AppearanceSection()
    }
    .scrollContentBackground(.hidden)
    .background(Theme.background)
}
