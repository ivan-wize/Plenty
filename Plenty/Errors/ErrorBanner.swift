//
//  ErrorBanner.swift
//  Plenty
//
//  Target path: Plenty/Errors/ErrorBanner.swift
//
//  Calm dismissible banner for user-facing errors. Color shifts by
//  severity (amber for soft, terracotta for hard). Tappable for more
//  detail; X to dismiss.
//
//  Used at the top of HomeTab. Other surfaces (sheets, sheets within
//  sheets) handle their own errors locally — this is for app-level
//  state.
//

import SwiftUI

struct ErrorBanner: View {

    @Binding var error: PlentyError?

    @State private var isExpanded = false

    var body: some View {
        if let error {
            VStack(alignment: .leading, spacing: 0) {
                header(for: error)

                if isExpanded {
                    detail(for: error)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(backgroundColor(for: error))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(borderColor(for: error), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Header

    private func header(for error: PlentyError) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: error))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accentColor(for: error))

                VStack(alignment: .leading, spacing: 1) {
                    Text(error.title)
                        .font(Typography.Body.emphasis)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !isExpanded {
                        Text("Tap for details")
                            .font(Typography.Support.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.snappy) {
                        self.error = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(8)
                        .background(Circle().fill(Color.secondary.opacity(Theme.Opacity.hairline)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    private func detail(for error: PlentyError) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(error.detail)
                .font(Typography.Body.regular)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if error.offersSettingsLink {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(Typography.Body.emphasis)
                        .foregroundStyle(accentColor(for: error))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Color Helpers

    private func accentColor(for error: PlentyError) -> Color {
        switch error.severity {
        case .soft: return Theme.amber
        case .hard: return Theme.terracotta
        }
    }

    private func backgroundColor(for error: PlentyError) -> Color {
        accentColor(for: error).opacity(Theme.Opacity.soft)
    }

    private func borderColor(for error: PlentyError) -> Color {
        accentColor(for: error).opacity(0.25)
    }

    private func iconName(for error: PlentyError) -> String {
        switch error {
        case .cloudKitSyncFailed:    return "icloud.slash"
        case .saveFailed:            return "exclamationmark.triangle"
        case .aiUnavailable:         return "sparkles"
        case .importFailed:          return "doc.badge.arrow.up.fill"
        case .calendarAccessDenied:  return "calendar.badge.exclamationmark"
        case .generic:               return "exclamationmark.circle"
        }
    }
}
