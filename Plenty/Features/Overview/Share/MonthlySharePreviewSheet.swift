//
//  MonthlySharePreviewSheet.swift
//  Plenty
//
//  Target path: Plenty/Features/Overview/Share/MonthlySharePreviewSheet.swift
//
//  Phase 3.2 (post-launch v1): the sheet that shows the user the
//  share card before they share it. Two UX wins:
//
//    • The user sees exactly what they're about to send. Plenty's
//      privacy story ("only the totals leave your device") becomes
//      visibly true — they can read every value on the card.
//    • Cancellation is one tap. Tapping the share button is a
//      deliberate confirmation, not an accidental swipe.
//
//  Rendering pipeline:
//
//    1. Sheet appears.
//    2. `.task` runs once, calling ImageRenderer on the card view at
//       3x scale. Output: a 1080×1080 UIImage.
//    3. The UIImage is wrapped in a Transferable conforming type and
//       handed to ShareLink.
//    4. While the image is rendering, the share button shows a
//       ProgressView. ImageRenderer is fast (sub-frame on real
//       hardware) so this is rarely visible.
//
//  Custom Transferable type rather than relying on SwiftUI.Image's
//  built-in conformance — gives us a stable PNG export with a
//  predictable filename and matches what most receiving apps expect.
//

import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

struct MonthlySharePreviewSheet: View {

    let monthLabel: String
    let snapshot: PlentySnapshot

    @Environment(\.dismiss) private var dismiss
    @State private var shareable: PlentyMonthlyShareImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    cardPreview
                    description
                    shareButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Share this month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .task { await renderImage() }
        }
    }

    // MARK: - Card Preview

    /// Shows the card at natural 360pt size on roomy phones, scales
    /// down to fit on narrower ones via ViewThatFits. Wrapped in a
    /// rounded rectangle clip so the gradient edge reads cleanly.
    private var cardPreview: some View {
        ViewThatFits {
            cardAtNaturalSize
            cardScaledToFit(scale: 0.92)
            cardScaledToFit(scale: 0.85)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.secondary.opacity(Theme.Opacity.hairline), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private var cardAtNaturalSize: some View {
        MonthlyShareCardView(monthLabel: monthLabel, snapshot: snapshot)
    }

    private func cardScaledToFit(scale: CGFloat) -> some View {
        MonthlyShareCardView(monthLabel: monthLabel, snapshot: snapshot)
            .scaleEffect(scale, anchor: .center)
            .frame(
                width: MonthlyShareCardLayout.size * scale,
                height: MonthlyShareCardLayout.size * scale
            )
    }

    // MARK: - Description

    private var description: some View {
        Text("Save to Photos, send via Messages, or post wherever you like. Only the totals leave your device.")
            .font(Typography.Body.regular)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
    }

    // MARK: - Share Button

    @ViewBuilder
    private var shareButton: some View {
        if let shareable {
            ShareLink(
                item: shareable,
                preview: SharePreview(
                    "\(monthLabel) — Plenty",
                    image: Image(uiImage: shareable.image)
                )
            ) {
                HStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                    Text("Share")
                        .font(Typography.Body.emphasis)
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.sage)
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.sage.opacity(0.6))
            )
        }
    }

    // MARK: - Render

    @MainActor
    private func renderImage() async {
        // Re-render is idempotent; guard so re-task doesn't redo the work.
        guard shareable == nil else { return }

        let renderer = ImageRenderer(
            content: MonthlyShareCardView(monthLabel: monthLabel, snapshot: snapshot)
        )
        renderer.scale = MonthlyShareCardLayout.renderScale

        guard let uiImage = renderer.uiImage else { return }
        shareable = PlentyMonthlyShareImage(image: uiImage)
    }
}

// MARK: - Transferable Wrapper

/// Wraps the rendered share card UIImage with a stable PNG export.
/// Custom Transferable rather than relying on `Image`'s built-in
/// conformance — gives a predictable filename (`plenty-month.png`)
/// and matches what receiving apps (Photos, Messages) expect.
struct PlentyMonthlyShareImage: Transferable {

    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { wrapper in
            guard let data = wrapper.image.pngData() else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
        .suggestedFileName("plenty-month.png")
    }
}
