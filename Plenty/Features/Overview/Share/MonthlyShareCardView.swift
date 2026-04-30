//
//  MonthlyShareCardView.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/Share/MonthlyShareCardView.swift
//
//  Phase 3.2 (post-launch v1): the visual surface that gets rendered
//  to a square 1080×1080 image and shared via ShareLink.
//
//  Design rules:
//
//  • Square (1:1) — universal aspect for Instagram, X, iMessage,
//    Photos. Avoids per-platform variants.
//  • Logical size 360×360 pt; render at 3x scale → 1080×1080 px.
//  • Sage gradient background. The brand horizon mark anchors the
//    top, the wordmark below it.
//  • Hero number is the only large element; the breakdown sits
//    quietly underneath. Plenty's voice rules apply — possession-
//    leading, no exclamations, no marketing flourish.
//  • Privacy: only aggregate numbers leave the device. No account
//    names, no transaction names, no notes.
//
//  Caller (MonthlySharePreviewSheet) is responsible for rendering
//  this view to UIImage via ImageRenderer and feeding it into a
//  ShareLink. The view itself is pure SwiftUI and contains no
//  rendering logic.
//

import SwiftUI

/// The exact size we render at. Keep in sync with
/// MonthlySharePreviewSheet so the rendered output matches the
/// preview the user sees on screen.
enum MonthlyShareCardLayout {
    /// Logical point size (square).
    static let size: CGFloat = 360
    /// Render scale factor; 3x produces a 1080×1080 image.
    static let renderScale: CGFloat = 3
}

struct MonthlyShareCardView: View {

    let monthLabel: String       // "April 2026"
    let snapshot: PlentySnapshot

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                Spacer()

                topBrand
                    .padding(.top, 32)

                Spacer()

                hero
                    .padding(.horizontal, 32)

                Spacer()

                breakdown
                    .padding(.horizontal, 40)

                Spacer()

                bottomBrand
                    .padding(.bottom, 32)
            }
        }
        .frame(width: MonthlyShareCardLayout.size, height: MonthlyShareCardLayout.size)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Theme.sage.opacity(0.08),
                Theme.background,
                Theme.sage.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Top Brand

    private var topBrand: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Theme.sage)
                .frame(width: 64, height: 7)

            Text("Plenty")
                .font(.system(size: 18, weight: .medium, design: .default))
                .tracking(-0.2)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 8) {
            Text(monthLabel)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .textCase(.uppercase)

            Text(formattedRemaining)
                .font(.system(size: 56, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(remainingColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("Left this month")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
        }
    }

    private var formattedRemaining: String {
        let value = snapshot.monthlyBudgetRemaining
        let abs = value < 0 ? -value : value
        let formatted = abs.asPlainCurrency()
        return value < 0 ? "−\(formatted)" : formatted
    }

    private var remainingColor: Color {
        let v = snapshot.monthlyBudgetRemaining
        if v > 0 { return Theme.sage }
        if v < 0 { return Theme.terracotta }
        return .primary
    }

    // MARK: - Breakdown

    private var breakdown: some View {
        VStack(spacing: 10) {
            statRow(label: "Income", value: snapshot.confirmedIncome)
            statRow(label: "Bills",  value: snapshot.billsTotal)
            statRow(label: "Spent",  value: snapshot.expensesThisMonth)
        }
    }

    private func statRow(label: String, value: Decimal) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.asPlainCurrency())
                .font(.system(size: 14, weight: .medium, design: .default).monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Bottom Brand

    private var bottomBrand: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Theme.sage.opacity(0.4))
                .frame(width: 32, height: 3)

            Text("plenty.app")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundStyle(.tertiary)
                .tracking(0.4)
        }
    }
}

// MARK: - Local Decimal Helper

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}

// MARK: - Previews

private extension PlentySnapshot {
    /// Minimal preview snapshot. Mirrors `HeroNumberView`'s pattern
    /// of building a fully-populated PlentySnapshot from a small
    /// number of inputs for previews and screenshots.
    static func sharePreview(
        monthlyBudgetRemaining: Decimal,
        confirmedIncome: Decimal,
        billsTotal: Decimal,
        expenses: Decimal
    ) -> PlentySnapshot {
        PlentySnapshot(
            spendable: monthlyBudgetRemaining,
            cashOnHand: confirmedIncome - billsTotal - expenses,
            cashAccountsTotal: confirmedIncome,
            creditCardDebt: 0,
            statementDueBeforeNextIncome: 0,
            billsRemaining: 0,
            billsTotal: billsTotal,
            billsPaid: billsTotal,
            expensesThisMonth: expenses,
            confirmedIncome: confirmedIncome,
            expectedIncome: 0,
            totalIncome: confirmedIncome,
            nextIncomeDate: nil,
            plannedSavingsThisMonth: 0,
            actualSavingsThisMonth: 0,
            plannedSavingsRemaining: 0,
            smoothedDailyBurn: 0,
            sustainableDailyBurn: nil,
            billsPaidCount: 0,
            billsTotalCount: 0,
            incomeConfirmedCount: 0,
            incomeTotalCount: 0,
            expensesByCategory: [],
            monthlyBudgetRemaining: monthlyBudgetRemaining
        )
    }
}

#Preview("Positive") {
    MonthlyShareCardView(
        monthLabel: "April 2026",
        snapshot: .sharePreview(
            monthlyBudgetRemaining: 1840,
            confirmedIncome: 4500,
            billsTotal: 1800,
            expenses: 860
        )
    )
    .background(Color.gray.opacity(0.1))
}

#Preview("Negative") {
    MonthlyShareCardView(
        monthLabel: "April 2026",
        snapshot: .sharePreview(
            monthlyBudgetRemaining: -240,
            confirmedIncome: 3200,
            billsTotal: 2400,
            expenses: 1040
        )
    )
    .background(Color.gray.opacity(0.1))
}
