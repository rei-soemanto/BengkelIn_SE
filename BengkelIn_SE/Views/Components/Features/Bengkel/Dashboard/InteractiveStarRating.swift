//
//  InteractiveStarRating.swift
//  BengkelIn_SE
//
//  Ported from MbengkelIn. Tappable star picker for submitting a rating (1...maxRating).
//

import SwiftUI

struct InteractiveStarRating: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 32

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...maxRating, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(value <= rating ? .yellow : Color.gray.opacity(0.4))
                    .onTapGesture { rating = value }
                    .accessibilityLabel("\(value) bintang")
            }
        }
    }
}
