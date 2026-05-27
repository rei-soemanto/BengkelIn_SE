//
//  MechanicProfileViewModel.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto.
//

import SwiftUI
import Supabase
import Combine

@MainActor
class MechanicProfileViewModel: ObservableObject {
    @Published var myBengkel: Bengkel?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let authService = AuthService()
    private let bengkelRepository = BengkelRepository()
    private let resignationRepository = MechanicResignationRepository()

    init() {}

    func fetchMyBengkel() async {
        guard self.myBengkel == nil else { return }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await bengkelRepository.fetchMyBengkelRPC()
            self.myBengkel = result
            print("✅ [MechanicProfileVM] Successfully loaded Bengkel: \(result.name)")
        } catch {
            print("⚠️ [MechanicProfileVM] User is not linked to a Bengkel or fetch failed: \(error)")
        }

        isLoading = false
    }

    func submitResignation(password: String) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "Authentication error. Please log in again."
            self.isSubmitting = false
            return false
        }

        let mechanicId = session.user.id.uuidString.lowercased()
        let email = session.user.email ?? ""

        guard let bengkelId = myBengkel?.id else {
            self.errorMessage = "You are not currently linked to a Bengkel."
            isSubmitting = false
            return false
        }

        do {
            // 1. Re-authenticate to confirm intent
            _ = try await authService.signIn(email: email, password: password)

            // 2. Submit resignation
            let payload = MechanicResignationInsert(
                bengkelId: bengkelId,
                mechanicId: mechanicId,
                status: "pending"
            )
            try await resignationRepository.insertResignation(payload)

            self.successMessage = "Resignation request sent to owner."
            isSubmitting = false
            return true
        } catch {
            self.errorMessage = "Resignation failed: \(error.localizedDescription)"
            isSubmitting = false
            return false
        }
    }
}
