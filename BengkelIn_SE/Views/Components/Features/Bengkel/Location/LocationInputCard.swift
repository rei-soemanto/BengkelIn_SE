//
//  LocationInputCard.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//
//  Tappable address display with a "use current location" button.
//  Binding-based, reusable: drop it into any view that needs an address picker.
//

import SwiftUI

struct LocationInputCard: View {
    @Binding var address: String
    @Binding var isFocused: Bool
    var isFetchingLocation: Bool
    var onCurrentLocationTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(.primary.opacity(0.7))

            // Tappable address area — opens the search overlay.
            Button {
                isFocused = true
            } label: {
                Text(address.isEmpty ? "Pick or search address…" : address)
                    .foregroundColor(address.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Current location button
            Button {
                onCurrentLocationTapped()
            } label: {
                if isFetchingLocation {
                    ProgressView()
                } else {
                    Image(systemName: "location.fill")
                        .foregroundColor(.primary.opacity(0.8))
                }
            }
            .disabled(isFetchingLocation)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
