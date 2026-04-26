//
//  OutlookView.swift
//  Plenty
//
//  Target path: Plenty/Features/Plan/OutlookView.swift
//
//  The Outlook mode of the Plan tab. Pulls IncomeSource and recurring
//  bills from the data layer, projects 12 months forward via
//  OutlookEngine, renders OutlookChart + a per-month detail list.
//

import SwiftUI
import SwiftData

struct OutlookView: View {

    @Query(filter: #Predicate<IncomeSource> { $0.isActive == true })
    private var incomeSources: [IncomeSource]

    @Query private var allTransactions: [Transaction]

    @Query(sort: \Account.sortOrder)
    private var allAccounts: [Account]

    @Environment(AppState.self) private var appState

    private var startingCash: Decimal {
        AccountDerivations.cashOnHand(allAccounts)
    }

    private var recurringBills: [Transaction] {
        allTransactions.filter { $0.kind == .bill && $0.recurringRule != nil }
    }

    private var months: [OutlookEngine.Month] {
        let cal = Calendar.current
        let m = cal.component(.month, from: .now)
        let y = cal.component(.year, from: .now)
        return OutlookEngine.project(
            startingCash: startingCash,
            from: m,
            year: y,
            incomeSources: incomeSources,
            recurringBills: recurringBills
        )
    }

    private var hasData: Bool {
        !incomeSources.isEmpty || !recurringBills.isEmpty
    }

    // MARK: - Body

    var body: some View {
        if !hasData {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    chartCard
                    monthList
                    disclosureFooter
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Twelve months ahead")
                .font(Typography.Title.small)

            Text("Projected from your active income and recurring bills, starting from \(startingCash.asPlainCurrency()) cash on hand today.")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projected ending cash")
                .font(Typography.Support.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            OutlookChart(months: months)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Month List

    private var monthList: some View {
        VStack(spacing: 0) {
            ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                monthRow(month)
                if index < months.count - 1 {
                    divider
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.cardSurface)
        )
        .padding(.horizontal, 16)
    }

    private func monthRow(_ month: OutlookEngine.Month) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(month.label) \(String(month.year))")
                    .font(Typography.Body.emphasis)
                    .foregroundStyle(.primary)

                Text(monthSubtitle(month))
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(month.projectedEndingCash.signedCurrency())
                    .font(Typography.Body.emphasis.monospacedDigit())
                    .foregroundStyle(month.projectedEndingCash < 0 ? Theme.terracotta : .primary)

                Text(netLabel(month.projectedNet))
                    .font(Typography.Support.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func monthSubtitle(_ month: OutlookEngine.Month) -> String {
        let inLabel = month.projectedIncome.asPlainCurrency()
        let outLabel = month.projectedBills.asPlainCurrency()
        return "\(inLabel) in · \(outLabel) out"
    }

    private func netLabel(_ net: Decimal) -> String {
        let abs = (net < 0 ? -net : net).asPlainCurrency()
        return net >= 0 ? "+\(abs) net" : "−\(abs) net"
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(Theme.Opacity.hairline))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    // MARK: - Disclosure

    private var disclosureFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How this projection works")
                .font(Typography.Body.emphasis)
                .foregroundStyle(.primary)

            Text("Plenty multiplies your active income sources by their cadence and subtracts your monthly recurring bills. It does not account for variable income, one-time expenses, statement balance cycles, or savings goal contributions. Use it as a directional guide, not a guarantee.")
                .font(Typography.Support.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Outlook needs your data", systemImage: "calendar")
        } description: {
            Text("Add a paycheck and a recurring bill or two so Plenty can project the road ahead.")
        } actions: {
            Button {
                appState.pendingAddSheet = .income(preferRecurring: true)
            } label: {
                Text("Add a paycheck").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.sage)
        }
    }
}

// MARK: - Decimal Helpers

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }

    func signedCurrency() -> String {
        let abs = self < 0 ? -self : self
        let formatted = abs.asPlainCurrency()
        return self < 0 ? "−\(formatted)" : formatted
    }
}
