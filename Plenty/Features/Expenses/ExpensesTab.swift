//
//  ExpensesTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Expenses/ExpensesTab.swift
//
//  Phase 5 (v2): the full Expenses tab.
//
//  Layout, top to bottom:
//    1. NavigationStack with toolbar:
//       - top-leading: scan document button (auto-routing)
//       - top-trailing: + → contextual add (transaction or bill,
//         depending on the selected sub-tab)
//    2. MonthNavigator
//    3. ExpensesSegmentedControl (Transactions | Bills)
//    4. The selected sub-tab's content view
//
//  Sub-tab persistence is local to this view's lifetime — flipping
//  between Income → Expenses keeps your sub-tab choice. That mirrors
//  iOS behavior people expect from segmented controls.
//

import SwiftUI

struct ExpensesTab: View {

    @Environment(AppState.self) private var appState
    @Environment(MonthScope.self) private var monthScope

    @State private var subTab: ExpensesSubTab = .transactions
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonthNavigator()
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                ExpensesSegmentedControl(selection: $subTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                content
                    .frame(maxHeight: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "doc.viewfinder")
                            .font(.body)
                            .foregroundStyle(Theme.sage)
                    }
                    .accessibilityLabel("Scan document")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        switch subTab {
                        case .transactions:
                            appState.pendingAddSheet = .expense
                        case .bills:
                            appState.pendingAddSheet = .bill()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.sage)
                    }
                    .accessibilityLabel(addButtonLabel)
                }
            }
            .sheet(isPresented: $showingScanner) {
                DocumentScannerView(mode: .auto) { result in
                    handleScannerResult(result)
                }
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch subTab {
        case .transactions:
            TransactionsListView()
        case .bills:
            BillsListView()
        }
    }

    private var addButtonLabel: String {
        switch subTab {
        case .transactions: return "Add transaction"
        case .bills:        return "Add bill"
        }
    }

    private func handleScannerResult(_ result: DocumentScanResult) {
        switch result {
        case .receipt(let draft, let image):
            appState.pendingAddSheet = .expenseFromScan(draft, image)
        case .bill(let draft, let image):
            appState.pendingAddSheet = .billFromScan(draft, image)
        case .manual(let image):
            // Default to expense, attach image so the user has it.
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
