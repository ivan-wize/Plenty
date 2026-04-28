//
//  OnboardingView.swift
//  Plenty
//
//  Target path: Plenty/Features/Onboarding/OnboardingView.swift
//
//  Phase 9 (v2): four-page onboarding aligned with v2's hero formula.
//
//    1. Welcome  — Plenty in one sentence (v2 voice)
//    2. Formula  — what the hero number actually is, with the
//                  + income / − bills / − expenses breakdown. NEW in v2.
//    3. Privacy  — what stays on device, what leaves
//    4. Picker   — Start fresh / Start with demo data
//
//  Wiring: PlentyApp checks `OnboardingView.shouldShow` at launch and
//  presents this as a fullScreenCover when true. Tapping either choice
//  marks onboarding complete and dismisses.
//
//  v2 voice rules apply throughout: second person, possession-leading,
//  no exclamations, no marketing flourish.
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
    private let lastPage = 3

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                formulaPage.tag(1)
                privacyPage.tag(2)
                pickerPage.tag(3)
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

    // MARK: - Welcome

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

                Text("It tells you how much of this month's money you have left. Pay once. Yours forever.")
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

    // MARK: - Formula (NEW in v2)

    private var formulaPage: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "equal.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text("One question, one number")
                    .font(Typography.Title.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Plenty's job is to answer this every day:")
                    .font(Typography.Body.regular)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            formulaCard
                .padding(.horizontal, 24)

            Text("Expected paychecks don't count until you confirm them. Bills count whether or not you've paid them.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
    }

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            formulaRow(symbol: "+", label: "Confirmed income",       color: Theme.sage)
            formulaRow(symbol: "−", label: "Bills (paid + unpaid)",  color: .secondary)
            formulaRow(symbol: "−", label: "Expenses you've logged", color: .secondary)
            Divider().padding(.vertical, 4)
            formulaRow(symbol: "=", label: "What's left this month", color: .primary, emphasis: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private func formulaRow(symbol: String, label: String, color: Color, emphasis: Bool = false) -> some View {
        HStack(spacing: 14) {
            Text(symbol)
                .font(.system(size: 18, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label)
                .font(emphasis ? Typography.Body.emphasis : Typography.Body.regular)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Privacy

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

    // MARK: - Picker

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
                    subtitle: "An empty app. Add your income and bills as you go.",
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
                        .fixedSize(horizontal: false, vertical: true)
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
