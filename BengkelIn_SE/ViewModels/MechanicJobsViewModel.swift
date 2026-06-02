//
//  MechanicJobsViewModel.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

// Mechanic-side active-job feed (UC2/E4). Lists jobs the provider dispatched to this
// mechanic; tapping one opens the shared route/work screen (BengkelRouteView).
@MainActor
class MechanicJobsViewModel: ObservableObject {
    @Published var jobs: [NearbyOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let assignmentRepository = MechanicAssignmentRepository()
    private let authService = AuthService()

    func fetchJobs() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let uid = try? await authService.currentUID() else {
                jobs = []
                isLoading = false
                return
            }
            jobs = try await assignmentRepository.fetchAssignedJobs(mechanicId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
