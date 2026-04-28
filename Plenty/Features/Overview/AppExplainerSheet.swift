//
//  AppExplainerSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/AppExplainerSheet.swift
//
//  Phase 3 (v2): the sheet shown when the user taps the info button
//  in the Overview top bar. Plain-language explanation of what Plenty
//  does, the formula, the four tabs, and the privacy promise (PDS
//  §4.1).
//
//  Voice rules per PDS §13: second person, possession-leading, calm,
//  no exclamations, no marketing flourish.
//

import SwiftUI

struct AppExplainerSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    formulaSection
                    tabsSection
                    privacySection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .background(Theme.background)
            .navigationTitle("How Plenty works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Wordmark(.title)
            Text("A budget planner that answers one question every day: how much of this month's money do you have left?")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Formula

    private var formulaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("The formula")

            VStack(alignment: .leading, spacing: 6) {
                formulaRow("+", "Confirmed income", Theme.sage)
                formulaRow("−", "Bills (paid + unpaid)", .secondary)
                formulaRow("−", "Expenses you've logged", .secondary)
                Divider().padding(.vertical, 4)
                formulaRow("=", "What's left this month", .primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )

            Text("Expected paychecks don't count until you confirm them. Bills count whether or not you've paid them yet — paying is bookkeeping, not new information.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formulaRow(_ symbol: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Text(symbol)
                .font(.system(size: 18, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label)
                .font(Typography.Body.regular)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Tabs

    private var tabsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("The four tabs")

            VStack(spacing: 0) {
                tabRow(
                    icon: "circle.grid.2x2",
                    title: "Overview",
                    description: "Your number, your last few transactions, your upcoming bills."
                )
                divider
                tabRow(
                    icon: "arrow.down.circle",
                    title: "Income",
                    description: "Recurring paychecks and one-time amounts. Confirm as money arrives."
                )
                divider
                tabRow(
                    icon: "arrow.up.circle",
                    title: "Expenses",
                    description: "Transactions and bills, both for the month you're looking at. Scan receipts to add quickly."
                )
                divider
                tabRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Plan",
                    description: "Your accounts (free), plus 12-month outlook, savings goals, and trends with Pro."
                )
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )
        }
    }

    private func tabRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(Theme.Opacity.hairline))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }

    // MARK: - Privacy

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your data stays yours")

            VStack(alignment: .leading, spacing: 12) {
                privacyRow(
                    icon: "iphone",
                    body: "Plenty stores everything on this device and in your private iCloud."
                )
                privacyRow(
                    icon: "wifi.slash",
                    body: "We never connect to a bank. You enter what you want to track."
                )
                privacyRow(
                    icon: "sparkles",
                    body: "Apple Intelligence runs on your iPhone. Nothing goes to a server."
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.cardSurface)
            )
        }
    }

    private func privacyRow(icon: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24, alignment: .center)
                .padding(.top, 1)

            Text(body)
                .font(Typography.Body.regular)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(Typography.Support.label)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

#Preview {
    AppExplainerSheet()
}
