//
//  AssignMechanicViewModel.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class AssignMechanicViewModel: ObservableObject {
    @Published var availableMechanics: [AvailableMechanic] = []
    @Published var isLoading = false
    @Published var isAssigning = false
    @Published var errorMessage: String?

    private let mechanicRepository = MechanicRepository()
    private let assignmentRepository = MechanicAssignmentRepository()

    func fetchAvailableMechanics(requestId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            availableMechanics = try await mechanicRepository.fetchAvailableMechanics(requestId: requestId)
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    @discardableResult
    func assign(requestId: String, mechanicId: String) async -> Bool {
        isAssigning = true
        errorMessage = nil
        do {
            try await assignmentRepository.assignMechanic(requestId: requestId, mechanicId: mechanicId)
            isAssigning = false
            return true
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
            isAssigning = false
            return false
        }
    }
}
