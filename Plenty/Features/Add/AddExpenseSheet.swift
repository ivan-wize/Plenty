//
//  AddExpenseSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/AddExpenseSheet.swift
//
//  Phase 7 (v2): SmartTransactionPredictor wired in.
//
//  As the user types in the name field, a debounced predict() call
//  runs against on-device history. When confidence ≥ 0.5 and the
//  user hasn't already filled amount + category, an inline
//  "Last time at..." suggestion appears below the name field with a
//  one-tap apply.
//
//  The prediction never overwrites existing input — if the user
//  already typed an amount, the apply only fills category, and vice
//  versa. The suggestion vanishes once the user is done typing or
//  applies it.
//
//  Three init paths (unchanged from P5):
//
//    AddExpenseSheet()
//      → Add a new expense from scratch.
//
//    AddExpenseSheet(existing: tx)
//      → Edit an existing expense.
//
//    AddExpenseSheet(initialDraft: receiptDraft, initialImage: data)
//      → Add a new expense pre-filled from a scanned receipt.
//
//    AddExpenseSheet(initialImage: data)
//      → Add a new expense with the receipt image attached.
//

import SwiftUI
import SwiftData

struct AddExpenseSheet: View {

    let existing: Transaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    @State private var amount: Decimal = 0
    @State private var name: String = ""
    @State private var category: TransactionCategory?
    @State private var sourceAccount: Account?
    @State private var date: Date = .now
    @State private var receiptImageData: Data?

    @State private var prediction: SmartPrediction?
    @State private var dismissedPredictionForName: String?

    @State private var showingCategoryPicker = false
    @State private var showingAccountPicker = false
    @State private var showingScanner = false
    @State private var showDeleteConfirmation = false

    @FocusState private var nameFocused: Bool

    // MARK: - Init

    init(
        existing: Transaction? = nil,
        initialDraft: ReceiptDraft? = nil,
        initialImage: Data? = nil
    ) {
        self.existing = existing

        if let existing {
            _amount = State(initialValue: existing.amount)
            _name = State(initialValue: existing.name)
            _category = State(initialValue: existing.category)
            _sourceAccount = State(initialValue: existing.sourceAccount)
            _date = State(initialValue: existing.date)
            _receiptImageData = State(initialValue: existing.receiptImageData)
        } else if let initialDraft {
            if let draftAmount = initialDraft.totalAmount {
                _amount = State(initialValue: draftAmount)
            }
            if let merchant = initialDraft.merchant {
                _name = State(initialValue: merchant)
            }
            _category = State(initialValue: initialDraft.category)
            if let draftDate = initialDraft.date {
                _date = State(initialValue: draftDate)
            }
            _receiptImageData = State(initialValue: initialImage)
        } else if let initialImage {
            _receiptImageData = State(initialValue: initialImage)
        }
    }

    private var isEditing: Bool { existing != nil }

    private var canSave: Bool {
        amount > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// True when the prediction is worth surfacing — high enough
    /// confidence, and there's actually something new to suggest the
    /// user hasn't already entered.
    private var shouldSurfacePrediction: Bool {
        guard let prediction, !isEditing else { return false }
        guard prediction.confidence >= 0.5 else { return false }
        guard dismissedPredictionForName != normalizedName else { return false }

        let canSuggestAmount = amount == 0 && prediction.amount != nil
        let canSuggestCategory = category == nil && prediction.category != nil
        return canSuggestAmount || canSuggestCategory
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                nameSection
                if shouldSurfacePrediction, let prediction {
                    predictionSection(prediction)
                }
                dateSection
                categorySection
                if !allAccounts.isEmpty {
                    accountSection
                }
                receiptSection
                if isEditing {
                    deleteSection
                }
            }
            .navigationTitle(isEditing ? "Edit expense" : "Add expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selection: $category, scope: .expense)
            }
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerView(
                    selection: $sourceAccount,
                    accounts: allAccounts,
                    spendableOnly: true
                )
            }
            .sheet(isPresented: $showingScanner) {
                DocumentScannerView(mode: .receipt) { result in
                    apply(scannerResult: result)
                }
                .ignoresSafeArea()
            }
            .confirmationDialog(
                "Delete this expense?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                if !isEditing && sourceAccount == nil {
                    sourceAccount = AccountDerivations.defaultSpendingSource(allAccounts)
                }
                if !isEditing { nameFocused = true }
            }
            .onChange(of: name) { _, _ in
                refreshPrediction()
            }
        }
    }

    // MARK: - Sections

    private var amountSection: some View {
        Section {
            HStack {
                Text("$")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                CurrencyField(value: $amount, prompt: "0", accent: Theme.sage)
            }
        }
    }

    private var nameSection: some View {
        Section("Description") {
            TextField("e.g. Groceries", text: $name)
                .focused($nameFocused)
                .textInputAutocapitalization(.sentences)
        }
    }

    private func predictionSection(_ prediction: SmartPrediction) -> some View {
        Section {
            Button {
                applyPrediction(prediction)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.body)
                        .foregroundStyle(Theme.sage)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Theme.sage.opacity(Theme.Opacity.soft)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(predictionPrimaryText(prediction))
                            .font(Typography.Body.regular)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(predictionSecondaryText(prediction))
                            .font(Typography.Support.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("Apply")
                        .font(Typography.Support.footnote.weight(.semibold))
                        .foregroundStyle(Theme.sage)
                }
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    dismissedPredictionForName = normalizedName
                } label: {
                    Label("Dismiss", systemImage: "xmark")
                }
            }
        } footer: {
            Text("Based on your past transactions. Swipe to dismiss.")
                .font(Typography.Support.caption)
        }
    }

    private func predictionPrimaryText(_ p: SmartPrediction) -> String {
        let displayName = p.displayName ?? "this vendor"
        if let amount = p.amount {
            return "Last time at \(displayName): \(amount.asPlainCurrency())"
        }
        if let category = p.category {
            return "Last time at \(displayName): \(category.displayName)"
        }
        return "Suggestion from history"
    }

    private func predictionSecondaryText(_ p: SmartPrediction) -> String {
        var parts: [String] = []
        if amount == 0, let predicted = p.amount {
            parts.append("Amount \(predicted.asPlainCurrency())")
        }
        if category == nil, let predictedCategory = p.category {
            parts.append("Category \(predictedCategory.displayName)")
        }
        if parts.isEmpty {
            return "\(p.matchCount) past entries"
        }
        return parts.joined(separator: " · ")
    }

    private var dateSection: some View {
        Section {
            DatePicker("Date", selection: $date, displayedComponents: .date)
        }
    }

    private var categorySection: some View {
        Section {
            Button {
                showingCategoryPicker = true
            } label: {
                HStack {
                    Text("Category")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let category {
                        HStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .foregroundStyle(Theme.sage)
                            Text(category.displayName)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Choose")
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var accountSection: some View {
        Section {
            Button {
                showingAccountPicker = true
            } label: {
                HStack {
                    Text("Paid from")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let sourceAccount {
                        Text(sourceAccount.name)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Choose")
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var receiptSection: some View {
        Section {
            if let receiptImageData {
                HStack {
                    ReceiptThumbnailView(imageData: receiptImageData)
                        .frame(width: 60, height: 60)
                    Text("Receipt attached")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        self.receiptImageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    showingScanner = true
                } label: {
                    HStack {
                        Image(systemName: "doc.viewfinder")
                            .foregroundStyle(Theme.sage)
                        Text("Scan receipt")
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("Plenty pulls the amount and category from your receipt automatically.")
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete this expense", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(isEditing ? "Save" : "Add") { save() }
                .fontWeight(.semibold)
                .disabled(!canSave)
        }
    }

    // MARK: - Prediction Wiring

    private func refreshPrediction() {
        let trimmed = normalizedName
        guard !trimmed.isEmpty else {
            prediction = nil
            return
        }
        let predictor = SmartTransactionPredictor(context: modelContext)
        prediction = predictor.predict(for: trimmed)

        // If the user typed past a previously-dismissed name, re-arm.
        if let dismissed = dismissedPredictionForName, dismissed != trimmed {
            dismissedPredictionForName = nil
        }
    }

    private func applyPrediction(_ p: SmartPrediction) {
        if amount == 0, let predictedAmount = p.amount {
            amount = predictedAmount
        }
        if category == nil, let predictedCategory = p.category {
            category = predictedCategory
        }
        // After apply, suppress the suggestion for this typed value.
        dismissedPredictionForName = normalizedName
    }

    // MARK: - Scanner Result

    private func apply(scannerResult: DocumentScanResult) {
        switch scannerResult {
        case .receipt(let draft, let image):
            if let draftAmount = draft.totalAmount, amount == 0 {
                amount = draftAmount
            }
            if let merchant = draft.merchant, name.isEmpty {
                name = merchant
            }
            if category == nil { category = draft.category }
            if let draftDate = draft.date {
                date = draftDate
            }
            if let image { receiptImageData = image }

        case .bill(_, let image), .manual(let image):
            if let image { receiptImageData = image }

        case .cancelled:
            break
        }
    }

    // MARK: - Save / Delete

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let existing {
            existing.amount = amount
            existing.name = trimmedName
            existing.category = category
            existing.sourceAccount = sourceAccount
            existing.date = date
            existing.receiptImageData = receiptImageData

            let cal = Calendar.current
            existing.month = cal.component(.month, from: date)
            existing.year = cal.component(.year, from: date)

            try? modelContext.save()
        } else {
            let new = Transaction.expense(
                name: trimmedName,
                amount: amount,
                date: date,
                category: category,
                sourceAccount: sourceAccount,
                receiptImageData: receiptImageData
            )
            modelContext.insert(new)
            try? modelContext.save()
        }

        dismiss()
    }

    private func delete() {
        guard let existing else { return }
        modelContext.delete(existing)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Decimal Helper

private extension Decimal {
    func asPlainCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }
}
