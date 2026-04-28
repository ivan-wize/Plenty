//
//  DocumentScannerView.swift
//  Plenty
//
//  Target path: Plenty/Features/Expenses/Scanning/DocumentScannerView.swift
//
//  Phase 5 (v2): the unified document scanner. Replaces the v1
//  ReceiptScannerView. Given a captured document, runs Vision OCR,
//  classifies the result via AIDocumentRouter, parses with the right
//  parser, and returns a DocumentScanResult to the caller.
//
//  Modes:
//    • .auto    — classify and route (FAB and Expenses tab `+` use
//                 this)
//    • .receipt — skip the classifier and always parse as a receipt.
//                 AddExpenseSheet's internal scan button uses this:
//                 the user is already in the expense flow, so we
//                 honor their intent.
//    • .bill    — symmetric: BillEditorSheet's scan button uses this
//                 to always parse as a bill.
//
//  Result cases:
//    • .receipt(ReceiptDraft, Data?) — caller presents AddExpenseSheet
//      with the draft and image.
//    • .bill(BillDraft, Data?) — caller presents BillEditorSheet.
//    • .manual(image: Data?) — AI unavailable or both parsers
//      returned nothing useful. Caller presents AddExpenseSheet with
//      just the image attached.
//    • .cancelled — user dismissed the scanner.
//

import SwiftUI
import VisionKit
import Vision
import os

private let logger = Logger(subsystem: "com.plenty.app", category: "document-scanner")

// MARK: - Mode and Result

enum DocumentScanMode: Sendable {
    case auto
    case receipt
    case bill
}

enum DocumentScanResult: Sendable {
    case receipt(ReceiptDraft, Data?)
    case bill(BillDraft, Data?)
    case manual(image: Data?)
    case cancelled
}

// MARK: - View

struct DocumentScannerView: UIViewControllerRepresentable {

    let mode: DocumentScanMode
    let onFinish: (DocumentScanResult) -> Void

    init(mode: DocumentScanMode = .auto, onFinish: @escaping (DocumentScanResult) -> Void) {
        self.mode = mode
        self.onFinish = onFinish
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, onFinish: onFinish)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {

        let mode: DocumentScanMode
        let onFinish: (DocumentScanResult) -> Void

        init(mode: DocumentScanMode, onFinish: @escaping (DocumentScanResult) -> Void) {
            self.mode = mode
            self.onFinish = onFinish
        }

        // MARK: VNDocumentCameraViewControllerDelegate

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Use the first page only — receipts and bills are
            // single-page in the overwhelming majority of cases. If we
            // ever support multi-page bills, that's a P10 follow-on.
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true) { [weak self] in
                    self?.onFinish(.cancelled)
                }
                return
            }
            let firstImage = scan.imageOfPage(at: 0)
            let imageData = firstImage.jpegData(compressionQuality: 0.7)

            controller.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    let result = await self.processImage(firstImage, imageData: imageData)
                    self.onFinish(result)
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [weak self] in
                self?.onFinish(.cancelled)
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            logger.error("Document scan failed: \(error.localizedDescription)")
            controller.dismiss(animated: true) { [weak self] in
                self?.onFinish(.cancelled)
            }
        }

        // MARK: Pipeline

        @MainActor
        private func processImage(_ image: UIImage, imageData: Data?) async -> DocumentScanResult {
            // 1. OCR
            let ocrText = await Self.recognizeText(in: image)
            guard let ocrText, !ocrText.isEmpty else {
                logger.info("OCR produced no text — manual fallback")
                return .manual(image: imageData)
            }

            // 2. Classify (or honor forced mode)
            let kind: AIDocumentRouter.DocumentKind = await {
                switch mode {
                case .receipt: return .receipt
                case .bill:    return .bill
                case .auto:    return await AIDocumentRouter.classify(ocrText)
                }
            }()

            // 3. Parse with the appropriate parser
            switch kind {
            case .receipt:
                if let draft = await AIReceiptParser.parse(ocrText) {
                    return .receipt(draft, imageData)
                }
                return .manual(image: imageData)

            case .bill:
                if let draft = await AIBillParser.parse(ocrText) {
                    return .bill(draft, imageData)
                }
                return .manual(image: imageData)

            case .unknown:
                // Try receipt as the more common default.
                if let draft = await AIReceiptParser.parse(ocrText) {
                    return .receipt(draft, imageData)
                }
                return .manual(image: imageData)
            }
        }

        // MARK: OCR

        private static func recognizeText(in image: UIImage) async -> String? {
            guard let cgImage = image.cgImage else { return nil }

            return await withCheckedContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        logger.error("Vision OCR error: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let text = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    continuation.resume(returning: text)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    logger.error("Vision handler error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
