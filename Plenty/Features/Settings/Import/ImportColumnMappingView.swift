//
//  ImportColumnMappingView.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/Import/ImportColumnMappingView.swift
//
//  Second stage of CSV import. Shows the auto-detected column mapping
//  with confidence indicators. User can override each column,
//  override the date format, and pick the target account.
//
//  Most imports flow through this screen with one tap on Continue —
//  detection handles the common cases. The override paths exist for
//  the long tail of weird bank exports.
//

import SwiftUI
import SwiftData

struct ImportColumnMappingView: View {

    @Bindable var session: CSVImportSession
    let onContinue: () -> Void

    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var showingAccountPicker = false

    private var spendableAccounts: [Account] {
        AccountDerivations.spendableAccounts(accounts)
    }

    private var canContinue: Bool {
        session.mapping != nil && session.dateFormat != nil && session.targetAccount != nil
    }

    // MARK: - Body

    var body: some View {
        Form {
            fileSection
            columnSection
            dateFormatSection
            accountSection
        }
        .safeAreaInset(edge: .bottom) {
            continueButton
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.bar)
        }
        .sheet(isPresented: $showingAccountPicker) {
            AccountPickerView(
                selection: $session.targetAccount,
                accounts: accounts,
                spendableOnly: true
            )
        }
        .onAppear {
            if session.targetAccount == nil {
                session.targetAccount = AccountDerivations.defaultSpendingSource(accounts)
            }
        }
    }

    // MARK: - File Section

    private var fileSection: some View {
        Section {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(Theme.sage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.fileName)
                        .font(Typography.Body.regular)
                        .lineLimit(1)
                    Text("\(session.parsedFile?.rowCount ?? 0) rows")
                        .font(Typography.Support.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Column Section

    private var columnSection: some View {
        Section {
            if let mapping = session.mapping, let parsedFile = session.parsedFile {
                columnRow(
                    label: "Date",
                    columnIndex: mapping.dateColumn,
                    confidence: mapping.dateConfidence,
                    headers: parsedFile.headers,
                    onSelect: { newIndex in
                        updateMapping(dateColumn: newIndex)
                    }
                )

                columnRow(
                    label: "Description",
                    columnIndex: mapping.descriptionColumn,
                    confidence: mapping.descriptionConfidence,
                    headers: parsedFile.headers,
                    onSelect: { newIndex in
                        updateMapping(descriptionColumn: newIndex)
                    }
                )

                amountSignRow(mapping: mapping, parsedFile: parsedFile)
            } else {
                Text("Couldn't detect columns. Choose manually below.")
                    .font(Typography.Body.regular)
                    .foregroundStyle(Theme.terracotta)
            }
        } header: {
            Text("Columns")
        } footer: {
            Text("Plenty guessed which column is which based on your file's headers and content. Override any of them if needed.")
                .font(Typography.Support.caption)
        }
    }

    private func columnRow(
        label: String,
        columnIndex: Int,
        confidence: Int,
        headers: [String],
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        Menu {
            ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                Button {
                    onSelect(index)
                } label: {
                    if index == columnIndex {
                        Label(header, systemImage: "checkmark")
                    } else {
                        Text(header)
                    }
                }
            }
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(headers.indices.contains(columnIndex) ? headers[columnIndex] : "?")
                        .foregroundStyle(.secondary)
                    confidenceBadge(confidence)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func amountSignRow(
        mapping: CSVColumnDetector.Mapping,
        parsedFile: CSVParser.ParsedFile
    ) -> some View {
        HStack {
            Text("Amount")
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(amountDescription(mapping.signConvention, headers: parsedFile.headers))
                    .foregroundStyle(.secondary)
                    .font(Typography.Body.regular)
                confidenceBadge(mapping.amountConfidence)
            }
        }
    }

    private func amountDescription(_ convention: CSVColumnDetector.SignConvention, headers: [String]) -> String {
        switch convention {
        case .signedAmount(let column):
            return headers.indices.contains(column) ? headers[column] : "?"
        case .debitCreditSplit(let debit, let credit):
            let debitName = headers.indices.contains(debit) ? headers[debit] : "?"
            let creditName = headers.indices.contains(credit) ? headers[credit] : "?"
            return "\(debitName) + \(creditName)"
        case .amountPlusIndicator(let amount, let indicator):
            let amountName = headers.indices.contains(amount) ? headers[amount] : "?"
            let indicatorName = headers.indices.contains(indicator) ? headers[indicator] : "?"
            return "\(amountName) + \(indicatorName)"
        }
    }

    private func confidenceBadge(_ confidence: Int) -> some View {
        let (label, color): (String, Color) = {
            if confidence >= 75 { return ("High match", Theme.sage) }
            if confidence >= 50 { return ("Medium match", Theme.amber) }
            return ("Verify", Theme.terracotta)
        }()
        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
    }

    // MARK: - Date Format Section

    private var dateFormatSection: some View {
        Section {
            Picker("Date format", selection: Binding(
                get: { session.dateFormat ?? .isoDate },
                set: { session.dateFormat = $0 }
            )) {
                ForEach(CSVDateParser.Format.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Date format")
        } footer: {
            Text("Plenty detected the format from a sample of your dates. If your import dates look off, change this here.")
                .font(Typography.Support.caption)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            Button {
                showingAccountPicker = true
            } label: {
                HStack {
                    Text("Target account")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let target = session.targetAccount {
                        Text(target.name)
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
        } header: {
            Text("Account")
        } footer: {
            Text("All imported transactions will be assigned to this account.")
                .font(Typography.Support.caption)
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            onContinue()
        } label: {
            HStack {
                Spacer()
                Text("Preview \(session.parsedFile?.rowCount ?? 0) Transactions")
                    .font(Typography.Body.emphasis)
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .background(canContinue ? Theme.sage : Color.secondary.opacity(0.4))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .disabled(!canContinue)
    }

    // MARK: - Helpers

    private func updateMapping(dateColumn: Int? = nil, descriptionColumn: Int? = nil) {
        guard let current = session.mapping else { return }
        session.mapping = CSVColumnDetector.Mapping(
            dateColumn: dateColumn ?? current.dateColumn,
            descriptionColumn: descriptionColumn ?? current.descriptionColumn,
            signConvention: current.signConvention,
            dateConfidence: dateColumn != nil ? 100 : current.dateConfidence,
            descriptionConfidence: descriptionColumn != nil ? 100 : current.descriptionConfidence,
            amountConfidence: current.amountConfidence
        )
    }
}
