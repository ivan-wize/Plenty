//
//  AboutSection.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/AboutSection.swift
//
//  PRD §9.17: "App version, privacy policy, terms of service, support
//  contact, acknowledgments."
//
//  URLs are placeholders in Phase 2. Phase 13 (Launch Prep) replaces
//  them with real production endpoints tied to the landing page.
//

import SwiftUI

struct AboutSection: View {

    var body: some View {
        Section("About") {
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
