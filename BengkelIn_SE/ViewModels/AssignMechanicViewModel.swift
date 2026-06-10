//
//  AssignMechanicViewModel.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

// Provider-side dispatch (UC2). Lists the bengkel's accepted mechanics (the roster
// seam read owned by Bryan) and assigns a job to one — or to "Self".
@MainActor
class AssignMechanicViewModel: ObservableObject {
    @Published var availableMechanics: [AvailableMechanic] = []
    @Published var isLoading = false
    @Published var isAssigning = false
    @Published var errorMessage: String?

    private let mechanicRepository = MechanicRepository()              // Bryan's roster read
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

    // Dispatch (or reassign) the order to a roster mechanic. Returns true on success.
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
