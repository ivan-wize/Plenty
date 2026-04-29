//
//  ReceiptThumbnailView.swift
//  Plenty
//
//  Created by Ivan Wize on 4/24/26.
//

import SwiftUI

struct ReceiptThumbnailView: View {
    let imageData: Data

    var body: some View {
        Group {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.cardSurface
                    Image(systemName: "doc.text.image")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}
