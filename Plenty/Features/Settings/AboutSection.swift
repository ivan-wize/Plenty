//
//  AboutSection.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/AboutSection.swift
//
//  Phase 1.4 (post-launch v1): adds an Apple Intelligence
//  availability row at the top of the About section. Two states only:
//
//    `.available`   → "On"  in sage
//    `.unavailable` → "Off" in secondary
//
//  Why surface this at all: when Apple Intelligence is off (device
//  not eligible, user disabled it in Settings, model still
//  downloading), Plenty's Read drops back to deterministic copy. The
//  user shouldn't have to guess why the inline insight feels less
//  alive. This row is the ground truth for what features are
//  on-device LLM-powered today.
//
//  ----- Earlier history -----
//
//  PRD §9.17: "App version, privacy policy, terms of service,
//  support contact, acknowledgments."
//
//  URLs are placeholders in Phase 2. Phase 13 (Launch Prep) replaces
//  them with real production endpoints tied to the landing page.
//

import SwiftUI
import FoundationModels

struct AboutSection: View {

    var body: some View {
        Section("About") {
            aiAvailabilityRow

            versionRow

            link(
                title: "Privacy policy",
                url: "https://plenty.app/privacy"
            )

            link(
                title: "Terms of service",
                url: "https://plenty.app/terms"
            )

            link(
                title: "Support",
                url: "https://plenty.app/support"
            )

            NavigationLink {
                AcknowledgmentsView()
            } label: {
                Text("Acknowledgments")
            }
        }
    }

    // MARK: - Apple Intelligence

    /// Reads `SystemLanguageModel.default.availability` once per
    /// render so both the label and the color stay in sync. The row
    /// is informational; tapping it does nothing — users manage
    /// Apple Intelligence in iOS Settings, not from inside Plenty.
    private var aiAvailabilityRow: some View {
        let state = aiState
        return HStack {
            Text("Apple Intelligence")
            Spacer()
            Text(state.label)
                .foregroundStyle(state.color)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Intelligence \(state.label)")
    }

    private var aiState: (label: String, color: Color) {
        switch SystemLanguageModel.default.availability {
        case .available:   return ("On",  Theme.sage)
        case .unavailable: return ("Off", .secondary)
        }
    }

    // MARK: - Version

    private var versionRow: some View {
        HStack {
            Text("Version")
            Spacer()
            Text(versionString)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Link Row

    private func link(title: String, url: String) -> some View {
        Group {
            if let url = URL(string: url) {
                Link(destination: url) {
                    HStack {
                        Text(title)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(title)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Acknowledgments

/// Minimal acknowledgments view. Phase 2 renders a calm one-liner;
/// real content (open-source licenses, etc.) arrives as dependencies
/// accrue. Plenty has zero third-party dependencies today, so there's
/// nothing to acknowledge yet.
private struct AcknowledgmentsView: View {

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Wordmark(.title)
                Text("Plenty is built on Apple frameworks only. No third-party dependencies.")
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        Form {
            AboutSection()
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }
}
