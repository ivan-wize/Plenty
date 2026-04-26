//
//  OnboardingView.swift
//  Plenty
//
//  Target path: Plenty/Features/Onboarding/OnboardingView.swift
//
//  Shown on first launch (and any time the user opens an empty app
//  with the "show onboarding" UserDefault still true). Three calm
//  pages plus a final picker:
//
//    1. Welcome — Plenty in one sentence
//    2. Privacy — what stays on the device, what leaves
//    3. Picker — Start fresh / Start with demo data
//
//  No bank-sync sales pitch, no marketing flourish. The PRD's voice
//  rules apply: second person, possession-leading, no exclamations.
//
//  Wiring: PlentyApp checks `OnboardingView.shouldShow` at launch and
//  presents this as a fullScreenCover when true. Tapping either choice
//  marks onboarding complete and dismisses.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {

    // MARK: - Show/Suppress

    private static let completedKey = "plenty.onboarding.completed"

    /// Whether the onboarding flow should appear on this launch.
    /// Returns true the first time PlentyApp asks, false after the
    /// user completes either choice.
    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    // MARK: - State

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var page: Int = 0
    private let lastPage = 2

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                privacyPage.tag(1)
                pickerPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            // The horizon mark from the app icon, scaled up.
            Capsule()
                .fill(Theme.sage)
                .frame(width: 200, height: 22)
                .padding(.bottom, 16)

            Text("Plenty")
                .font(.system(size: 48, weight: .medium, design: .default))
                .tracking(-0.5)
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                Text("A calm budget planner for iPhone.")
                    .font(Typography.Title.small)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("It tells you what you have, not what you've spent. Pay once. Yours forever.")
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var privacyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text("Your data stays yours")
                    .font(Typography.Title.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    privacyRow(
                        icon: "iphone",
                        title: "On your device",
                        body: "Plenty stores everything locally and in your private iCloud."
                    )
                    privacyRow(
                        icon: "wifi.slash",
                        title: "No bank connections",
                        body: "You enter what you want to track. We never connect to a bank."
                    )
                    privacyRow(
                        icon: "sparkles",
                        title: "On-device intelligence",
                        body: "Apple Intelligence runs on your iPhone. Nothing goes to a server."
                    )
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    private var pickerPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "leaf")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)

            Text("Where would you like to start?")
                .font(Typography.Title.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                pickerCard(
                    icon: "square.dashed",
                    title: "Start fresh",
                    subtitle: "An empty app. Add your accounts and bills as you go.",
                    accent: Theme.sage,
                    action: startFresh
                )

                pickerCard(
                    icon: "wand.and.stars",
                    title: "Start with demo data",
                    subtitle: "Explore every screen with a sample household. Clear it anytime.",
                    accent: Theme.amber,
                    action: startWithDemo
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Sub-Views

    private func privacyRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.primary)
                Text(body)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func pickerCard(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(accent)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(accent.opacity(Theme.Opacity.soft)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.Body.emphasis)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if page < lastPage {
            Button {
                withAnimation { page += 1 }
            } label: {
                Text("Continue")
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .fill(Theme.sage)
                    )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 1)
        }
    }

    // MARK: - Actions

    private func startFresh() {
        Self.markCompleted()
        dismiss()
    }

    private func startWithDemo() {
        // Safety: clear anything already there before seeding so we
        // don't double up (e.g. user reset onboarding via dev flag).
        if DemoModeService.isActive {
            DemoModeService.clearAll(modelContext: modelContext)
        }
        DemoModeService.seed(modelContext: modelContext)
        Self.markCompleted()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
