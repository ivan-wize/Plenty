//
//  ReceiptScannerView.swift
//  Plenty
//
//  Target path: Plenty/Features/Add/ReceiptScannerView.swift
//
//  Sheet that scans a paper receipt and returns a structured
//  ReceiptDraft. Three steps:
//
//    1. Present VNDocumentCameraViewController (UIKit-bridged) for the
//       user to shoot the receipt. They get document edge detection,
//       perspective correction, and the option to retake.
//    2. Run Vision text recognition on the resulting image.
//    3. Pipe the OCR text to AIReceiptParser for structured extraction.
//
//  Returns the ReceiptDraft + the captured image data (so it can be
//  saved on the Transaction for receipt history) via the onFinish
//  closure. The caller (AddExpenseSheet) pre-fills its fields and
//  dismisses the scanner.
//
//  If Apple Intelligence is unavailable, the OCR text is still
//  captured and the user is shown a "Couldn't auto-fill — please
//  enter manually" toast. The image is still returned so they can at
//  least save the receipt for their records.
//

import SwiftUI
import VisionKit
import Vision
import UIKit
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "receipt-scanner")

struct ReceiptScannerView: View {

    /// Called once the user has scanned, OCR has run, and the AI
    /// parser has had a chance. The draft may have nil fields where
    /// the parser couldn't extract; the image data is always present
    /// when this is called with a non-nil result.
    let onFinish: (ReceiptDraft?, Data?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .scanning
    @State private var capturedImage: UIImage?
    @State private var ocrText: String = ""
    @State private var draft: ReceiptDraft?

    enum Phase: Equatable {
        case scanning
        case processing
        case unavailable
    }

    var body: some View {
        Group {
            switch phase {
            case .scanning:
                DocumentScannerRepresentable(
                    onFinish: handleScanFinished,
                    onCancel: { onFinish(nil, nil); dismiss() }
                )
                .ignoresSafeArea()
            case .processing:
                processingView
            case .unavailable:
                unavailableView
            }
        }
    }

    // MARK: - Processing view

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.sage)
            Text("Reading the receipt…")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera not available on this device.")
                .font(Typography.Body.regular)
                .foregroundStyle(.secondary)
            Button("Done") {
                onFinish(nil, nil)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.sage)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: - Scan handling

    private func handleScanFinished(_ image: UIImage?) {
        guard let image else {
            onFinish(nil, nil)
            dismiss()
            return
        }
        capturedImage = image
        phase = .processing

        Task {
            // 1. OCR the captured image.
            let text = await runOCR(on: image)
            ocrText = text

            // 2. Compress the image for storage.
            let imageData = image.jpegData(compressionQuality: 0.7)

            // 3. Pipe OCR text to AI parser.
            let parsed = await AIReceiptParser.parse(text)

            await MainActor.run {
                onFinish(parsed, imageData)
                dismiss()
            }
        }
    }

    // MARK: - OCR

    private func runOCR(on image: UIImage) async -> String {
        guard let cgImage = image.cgImage else {
            logger.warning("Receipt scan: no cgImage available.")
            return ""
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    logger.error("OCR failed: \(error.localizedDescription)")
                    continuation.resume(returning: "")
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                logger.error("OCR handler perform failed: \(error.localizedDescription)")
                continuation.resume(returning: "")
            }
        }
    }
}

// MARK: - VNDocumentCamera bridge

private struct DocumentScannerRepresentable: UIViewControllerRepresentable {

    let onFinish: (UIImage?) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {

        let onFinish: (UIImage?) -> Void
        let onCancel: () -> Void

        init(onFinish: @escaping (UIImage?) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Take the first page only. Multi-page receipt scanning is
            // out of scope for V1.
            let image: UIImage? = scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil
            controller.dismiss(animated: true)
            onFinish(image)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            logger.error("Document scan failed: \(error.localizedDescription)")
            controller.dismiss(animated: true)
            onFinish(nil)
        }
    }
}
