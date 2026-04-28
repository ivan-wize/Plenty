//
//  MonthNavigator.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/Components/MonthNavigator.swift
//
//  Phase 2 (v2): the month/year scope control used at the top of every
//  tab (Overview, Income, Expenses, Plan in P6).
//
//  Layout:
//
//      ‹    April 2026    ›
//
//  Behavior:
//    • Left chevron — `MonthScope.stepBack()`
//    • Right chevron — `MonthScope.stepForward()`
//    • Tap the label — open a month/year picker for fast jumps
//    • Long-press the label — reset to the current calendar month
//
//  Reads the env-injected `MonthScope`. Never owns its own state.
//
//  Boundaries: optional via `earliestAllowed` and `latestAllowed`
//  parameters. When unset (default), navigation is unbounded — past
//  and future months are equally accessible per PDS §3.1.
//

import SwiftUI

struct MonthNavigator: View {

    // MARK: - Bounds (optional)

    /// Earliest month the user can step back to. Inclusive. Nil = unbounded.
    var earliestAllowed: Date?

    /// Latest month the user can step forward to. Inclusive. Nil = unbounded.
    var latestAllowed: Date?

    // MARK: - State

    @Environment(MonthScope.self) private var monthScope
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingPicker = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            chevronButton(
                systemImage: "chevron.left",
                accessibilityLabel: "Previous month",
                isEnabled: canStepBack,
                action: stepBack
            )

            Spacer(minLength: 0)

            label

            Spacer(minLength: 0)

            chevronButton(
                systemImage: "chevron.right",
                accessibilityLabel: "Next month",
                isEnabled: canStepForward,
                action: stepForward
            )
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .sheet(isPresented: $showingPicker) {
            MonthPickerSheet(
                month: monthScope.month,
                year: monthScope.year,
                earliestAllowed: earliestAllowed,
                latestAllowed: latestAllowed,
                onPick: { date in
                    monthScope.jumpTo(date: date)
                    showingPicker = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Label

    private var label: some View {
        Button {
            showingPicker = true
        } label: {
            Text(monthScope.displayLabel)
                .font(Typography.Body.emphasis.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(minWidth: 140)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .snappy, value: monthScope.year * 100 + monthScope.month)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                resetToCurrent()
            }
        )
        .accessibilityLabel(monthScope.displayLabel)
        .accessibilityHint("Tap to pick a month, or long-press to return to the current month.")
    }

    // MARK: - Chevron Button

    private func chevronButton(
        systemImage: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? Theme.sage : Color.secondary.opacity(0.4))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .sensoryFeedback(.selection, trigger: monthScope.month + monthScope.year * 100)
    }

    // MARK: - Actions

    private func stepBack() {
        guard canStepBack else { return }
        monthScope.stepBack()
    }

    private func stepForward() {
        guard canStepForward else { return }
        monthScope.stepForward()
    }

    private func resetToCurrent() {
        monthScope.resetToCurrent()
    }

    // MARK: - Boundary Checks

    private var canStepBack: Bool {
        guard let earliest = earliestAllowed else { return true }
        let cal = Calendar.current
        let earliestMonth = cal.component(.month, from: earliest)
        let earliestYear = cal.component(.year, from: earliest)
        if monthScope.year > earliestYear { return true }
        if monthScope.year < earliestYear { return false }
        return monthScope.month > earliestMonth
    }

    private var canStepForward: Bool {
        guard let latest = latestAllowed else { return true }
        let cal = Calendar.current
        let latestMonth = cal.component(.month, from: latest)
        let latestYear = cal.component(.year, from: latest)
        if monthScope.year < latestYear { return true }
        if monthScope.year > latestYear { return false }
        return monthScope.month < latestMonth
    }
}

// MARK: - Month Picker Sheet

private struct MonthPickerSheet: View {

    let month: Int
    let year: Int
    let earliestAllowed: Date?
    let latestAllowed: Date?
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selection: Date

    init(
        month: Int,
        year: Int,
        earliestAllowed: Date?,
        latestAllowed: Date?,
        onPick: @escaping (Date) -> Void
    ) {
        self.month = month
        self.year = year
        self.earliestAllowed = earliestAllowed
        self.latestAllowed = latestAllowed
        self.onPick = onPick

        let comps = DateComponents(year: year, month: month, day: 1)
        _selection = State(initialValue: Calendar.current.date(from: comps) ?? .now)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Month",
                    selection: $selection,
                    in: dateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()

                Spacer()

                Button {
                    onPick(selection)
                } label: {
                    Text("Go to month")
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Theme.background)
            .navigationTitle("Pick a month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private var dateRange: ClosedRange<Date> {
        let lower = earliestAllowed ?? Calendar.current.date(byAdding: .year, value: -10, to: .now) ?? .distantPast
        let upper = latestAllowed ?? Calendar.current.date(byAdding: .year, value: 10, to: .now) ?? .distantFuture
        return lower...upper
    }
}
