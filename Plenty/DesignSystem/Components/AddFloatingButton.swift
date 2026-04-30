//
//  AddFloatingButton.swift
//  Plenty
//
//  Target path: Plenty/DesignSystem/Components/AddFloatingButton.swift
//
//  Phase 2.2 (post-launch v1): tab-aware menu. The FAB now lives at
//  the RootView overlay level rather than per-tab, and adapts its
//  menu order based on the active tab so the most likely add action
//  leads.
//
//  Menu composition:
//
//    Overview  → transaction · bill · income · scan
//    Income    → income · transaction · bill · scan
//    Expenses  → transaction · bill · income · scan
//    Plan      → transaction · bill · income · scan
//
//  Design notes:
//
//  • Plan tab intentionally omits "Add account" — PlanAccountsView
//    already exposes both an inline `plus.circle` next to its
//    Accounts header and a CTA in its empty state. Surfacing the
//    same action in the FAB would compete with the contextual
//    affordance the user is already looking at.
//
//  • Expenses tab's sub-tab (Transactions vs Bills) is intentionally
//    not surfaced through the FAB. Adding sub-tab awareness would
//    couple the FAB to ExpensesTab's internal state. Lead is always
//    `transaction` since transactions outnumber bills several-to-one
//    in normal use, and "Add bill" is one tap away as the second
//    item.
//
//  • Scan stays last, always. It's a higher-friction path (camera
//    permission, holding the phone steady) so it doesn't earn
//    primary placement on any tab.
//
//  ----- Earlier history -----
//
//  Phase 5 (v2): three-item menu now that the document scanner can
//  route a captured page to the right editor automatically.
//

import SwiftUI

struct AddFloatingButton: View {

    /// The active tab. Drives menu ordering so the most likely add
    /// action leads.
    let tab: AppState.Tab

    @Environment(AppState.self) private var appState

    /// Diameter of the circular button. 56pt matches Apple's spec for
    /// floating action buttons.
    var size: CGFloat = 56

    @State private var showingScanner = false

    var body: some View {
        Menu {
            ForEach(menuItems, id: \.self) { item in
                Button {
                    perform(item)
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Theme.sage)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
        .accessibilityHint(accessibilityHint)
        .sensoryFeedback(.impact(weight: .medium), trigger: appState.pendingAddSheet?.id)
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView(mode: .auto) { result in
                handleScannerResult(result)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Menu Items

    enum MenuItem: Hashable {
        case income
        case transaction
        case bill
        case scan

        var title: String {
            switch self {
            case .income:      return "Add income"
            case .transaction: return "Add transaction"
            case .bill:        return "Add bill"
            case .scan:        return "Scan document"
            }
        }

        var systemImage: String {
            switch self {
            case .income:      return "arrow.down.circle"
            case .transaction: return "creditcard"
            case .bill:        return "doc.text"
            case .scan:        return "doc.viewfinder"
            }
        }
    }

    private var menuItems: [MenuItem] {
        switch tab {
        case .overview: return [.transaction, .bill, .income, .scan]
        case .income:   return [.income, .transaction, .bill, .scan]
        case .expenses: return [.transaction, .bill, .income, .scan]
        case .plan:     return [.transaction, .bill, .income, .scan]
        }
    }

    private var accessibilityHint: String {
        switch tab {
        case .income:
            return "Add income, a transaction, a bill, or scan a document."
        default:
            return "Add a transaction, a bill, income, or scan a document."
        }
    }

    // MARK: - Actions

    private func perform(_ item: MenuItem) {
        switch item {
        case .income:
            appState.pendingAddSheet = .income(preferRecurring: true)
        case .transaction:
            appState.pendingAddSheet = .expense
        case .bill:
            appState.pendingAddSheet = .bill()
        case .scan:
            showingScanner = true
        }
    }

    private func handleScannerResult(_ result: DocumentScanResult) {
        switch result {
        case .receipt(let draft, let image):
            appState.pendingAddSheet = .expenseFromScan(draft, image)
        case .bill(let draft, let image):
            appState.pendingAddSheet = .billFromScan(draft, image)
        case .manual(let image):
            // AI didn't classify confidently. Default to expense, but
            // attach the image so the user has it.
            if let image {
                let blank = ReceiptDraft(merchant: nil, totalAmount: nil, date: nil, category: nil)
                appState.pendingAddSheet = .expenseFromScan(blank, image)
            } else {
                appState.pendingAddSheet = .expense
            }
        case .cancelled:
            break
        }
    }
}
