//
//  OrderRatingViewModel.swift
//  BengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class OrderRatingViewModel: ObservableObject {
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let orderRepository = OrderRepository()

    func submit(requestId: String, rating: Int) async -> Bool {
        guard (1...5).contains(rating) else {
            errorMessage = "Pilih jumlah bintang terlebih dahulu."
            return false
        }
        isSubmitting = true
        errorMessage = nil
        do {
            try await orderRepository.submitRating(requestId: requestId, rating: rating)
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}
