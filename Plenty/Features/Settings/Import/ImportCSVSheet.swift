//
//  ImportCSVSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Settings/Import/ImportCSVSheet.swift
//
//  Entry point for CSV import. Holds the CSVImportSession and routes
//  to the correct view based on session.stage.
//
//  Flow:
//    1. .picking      → file picker (UIDocumentPicker)
//    2. .mapping      → ImportColumnMappingView
//    3. .preview      → ImportPreviewView
//    4. .importing    → progress
//    5. .complete     → ImportCompleteView
//    6. .failed       → error view
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportCSVSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var session = CSVImportSession()
    @State private var showingFileImporter = false
    @State private var fileImportError: String?

    @Query private var existingTransactions: [Transaction]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", role: .cancel) { dismiss() }
                    }
                }
                .background(Theme.background)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .onAppear {
            if case .picking = session.stage {
                showingFileImporter = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.stage {
        case .picking:
            pickingPlaceholder
        case .mapping:
            ImportColumnMappingView(session: session) {
                advanceToPreview()
            }
        case .preview:
            ImportPreviewView(session: session) {
                runImport()
            }
        case .importing:
            importingProgress
        case .complete(let imported, let skipped):
            ImportCompleteView(imported: imported, skipped: skipped) {
                dismiss()
            }
        case .failed(let message):
            failureView(message: message)
        }
    }

    // MARK: - Picking Placeholder

    private var pickingPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.sage)
                .symbolRenderingMode(.hierarchical)

            Text("Pick a CSV file from Files")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)

            Button {
                showingFileImporter = true
            } label: {
                Text("Choose File")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.sage)

            if let fileImportError {
                Text(fileImportError)
                    .font(Typography.Support.footnote)
                    .foregroundStyle(Theme.terracotta)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Importing Progress

    private var importingProgress: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.large)
                .tint(Theme.sage)

            Text("Importing \(session.includedCount) transactions...")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Failure

    private func failureView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.terracotta)
                .symbolRenderingMode(.hierarchical)

            Text("Import failed")
                .font(Typography.Title.small)

            Text(message)
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                session.reset()
                showingFileImporter = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.sage)

            Button("Cancel", role: .cancel) {
                dismiss()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - File Selection

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadFile(from: url)
        case .failure(let error):
            fileImportError = error.localizedDescription
        }
    }

    private func loadFile(from url: URL) {
        // Security-scoped resource access for the document picker.
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
                fileImportError = "Couldn't read the file as text. Is it really a CSV?"
                return
            }

            let parsed = try CSVParser.parse(text)
            session.fileName = url.lastPathComponent
            session.parsedFile = parsed

            // Auto-detect column mapping from the first 10 rows.
            let sample = Array(parsed.rows.prefix(10))
            session.mapping = CSVColumnDetector.detect(headers: parsed.headers, sampleRows: sample)

            // Auto-detect date format from the date column samples.
            if let mapping = session.mapping {
                let dateSamples = sample.compactMap { row in
                    row.indices.contains(mapping.dateColumn) ? row[mapping.dateColumn] : nil
                }
                if let detected = CSVDateParser.detectFormat(from: dateSamples) {
                    session.dateFormat = detected.format
                }
            }

            session.stage = .mapping
            fileImportError = nil
        } catch {
            session.stage = .failed(error.localizedDescription)
        }
    }

    // MARK: - Stage Transitions

    private func advanceToPreview() {
        session.buildCandidates(against: existingTransactions)
        session.stage = .preview
    }

    private func runImport() {
        session.stage = .importing
        Task { @MainActor in
            // Brief delay so the spinner has time to render even on
            // fast imports.
            try? await Task.sleep(nanoseconds: 300_000_000)
            let result = session.commit(modelContext: modelContext)
            session.stage = .complete(imported: result.imported, skipped: result.skipped)
        }
    }
}

// MARK: - Equatable for Stage matching

private extension CSVImportSession.Stage {
    static var stagePicking: CSVImportSession.Stage { .picking }
}
