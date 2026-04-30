//
//  ExpensesTab.swift
//  Plenty
//
//  Target path: Plenty/Features/Expenses/ExpensesTab.swift
//
//  Phase 2.2 (post-launch v1): the trailing `+` toolbar button is
//  removed. The root-level AddFloatingButton handles adds with
//  "Add transaction" leading the menu when this tab is active.
//
//  Note: the FAB doesn't see the sub-tab (Transactions vs Bills).
//  Lead is always `transaction`. When the user is on Bills sub-tab
//  and wants to add a bill, they tap the FAB and choose "Add bill"
//  (the second item). Surfacing sub-tab state through AppState would
//  let the FAB adapt further; deferred until there's evidence users
//  actually want it.
//
//  The leading scanner button stays — it's a complementary entry
//  point that the FAB also offers, but co-locating it with the
//  Expenses chrome makes the receipt → expense flow especially
//  fast (one tap from the tab to the camera).
//
//  ----- Earlier history -----
//
//  Phase 5 (v2): the full Expenses tab.
//
//  Layout, top to bottom:
//    1. NavigationStack with toolbar:
//       - top-leading: scan document button (auto-routing)
//       - (trailing + removed in Phase 2.2)
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
