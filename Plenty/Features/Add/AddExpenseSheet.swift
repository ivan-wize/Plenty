//
//  AddExpenseSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/AddExpenseSheet.swift
//
//  Quick add for a one-time expense. The most-used Add sheet.
//
//  Fields: amount, name, category (auto-detected from name; AI when
//  available, rules otherwise), source account (defaults to most-recent
//  spendable), date (defaults to today), optional receipt.
//
//  Replaces the prior AddExpenseSheet. Two changes:
//    • Toolbar gains a camera button that opens ReceiptScannerView.
//      A successful scan pre-fills amount, name, category, and date,
//      and stores the captured image data on the saved Transaction.
//    • A receipt thumbnail row appears under the date when an image
//      is attached, with a "Remove" tap target.
//

import SwiftUI
import SwiftData

struct AddExpenseSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    @State private var amount: Decimal = 0
    @State private var name: String = ""
    @State private var category: TransactionCategory?
    @State private var sourceAccount: Account?
    @State private var date: Date = .now
    @State private var receiptImageData: Data?

    @State private var showingCategoryPicker = false
    @State private var showingAccountPicker = false
    @State private var showingScanner = false

    @FocusState private var nameFocused: Bool

    private var canSave: Bool {
        amount > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                nameSection
                categorySection
                accountSection
                dateSection
                receiptSection
            }
            .navigationTitle("Add Expense")
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
                ReceiptScannerView(onFinish: applyScannedReceipt)
            }
            .onAppear {
                if sourceAccount == nil {
                    sourceAccount = AccountDerivations.defaultSpendingSource(allAccounts)
                }
            }
            .onChange(of: name) { _, newValue in
                Task { await autoDetectCategory(for: newValue) }
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
        Section("What for?") {
            TextField("e.g. Trader Joe's, gas, coffee", text: $name)
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
                .onAppear {
                    if name.isEmpty { nameFocused = true }
                }
        }
    }

    @ViewBuilder
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

    @ViewBuilder
    private var accountSection: some View {
        if !allAccounts.isEmpty {
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
    }

    private var dateSection: some View {
        Section {
            DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
        }
    }

    @ViewBuilder
    private var receiptSection: some View {
        if let data = receiptImageData, let image = UIImage(data: data) {
            Section("Receipt") {
                HStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Receipt attached")
                            .font(Typography.Body.regular)
                        Text("Will be saved with this expense.")
                            .font(Typography.Support.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        receiptImageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
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
            HStack(spacing: 16) {
                Button {
                    nameFocused = false
                    showingScanner = true
                } label: {
                    Image(systemName: "doc.text.viewfinder")
                }
                .accessibilityLabel("Scan receipt")

                Button("Add") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
    }

    // MARK: - Actions

    private func save() {
        let tx = Transaction.expense(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            date: date,
            category: category,
            sourceAccount: sourceAccount,
            receiptImageData: receiptImageData
        )
        modelContext.insert(tx)
        try? modelContext.save()
        dismiss()
    }

    private func autoDetectCategory(for name: String) async {
        guard category == nil else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return }

        if let aiCategory = await AIExpenseCategorizer.categorize(trimmed) {
            await MainActor.run { category = aiCategory }
        } else {
            let ruleCategory = ExpenseCategorizer.detect(from: trimmed)
            if ruleCategory != .other {
                await MainActor.run { category = ruleCategory }
            }
        }
    }

    // MARK: - Scanner Result Handling

    private func applyScannedReceipt(_ draft: ReceiptDraft?, _ imageData: Data?) {
        // Always store the image when one is captured, even if AI parsing
        // failed — at least the user gets a copy of the receipt.
        if let imageData {
            receiptImageData = imageData
        }

        guard let draft else { return }

        // Pre-fill empty fields only. Don't clobber anything the user
        // already typed before launching the scanner.
        if let merchant = draft.merchant, name.isEmpty {
            name = merchant
        }
        if let total = draft.totalAmount, amount == 0 {
            amount = total
        }
        if let scanDate = draft.date {
            date = scanDate
        }
        if let scannedCategory = draft.category, category == nil {
            category = scannedCategory
        }
    }
}
