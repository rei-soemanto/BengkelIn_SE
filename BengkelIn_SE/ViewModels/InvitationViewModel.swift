//
//  InvitationViewModel.swift
//  BengkelIn_SE
//
//  Created for Mechanic Invitation feature on 07/05/26.
//

import SwiftUI
import Supabase
import Combine

// MARK: - InvitationViewModel
// Handles fetching the current mechanic user's pending invitations and responding to them.

@MainActor
class InvitationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var pendingInvitations: [MechanicInvitationDisplay] = []
    @Published var isLoading = false
    @Published var isResponding = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let authService = AuthService()
    private let invitationRepository = MechanicInvitationRepository()

    // MARK: - Fetch Pending Invitations

    func fetchPendingInvitations() async {
        isLoading = true
        errorMessage = nil

        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "You must be logged in."
            isLoading = false
            return
        }
        let uid = session.user.id.uuidString.lowercased()

        do {
            let invitations = try await invitationRepository.fetchPendingForMechanic(mechanicId: uid)
            self.pendingInvitations = invitations
        } catch is CancellationError {
            // Task cancelled by SwiftUI navigation — silent.
        } catch {
            self.errorMessage = "Failed to load invitations."
            print("[InvitationVM] fetchPendingInvitations error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Respond to Invitation

    /// Accept or reject an invitation. Routes through the corresponding secure RPC.
    func respondToInvite(inviteId: String, accept: Bool) async -> Bool {
        isResponding = true
        errorMessage = nil
        successMessage = nil

        guard (try? await authService.getCurrentSession()) != nil else {
            self.errorMessage = "You must be logged in."
            isResponding = false
            return false
        }

        let success = accept
            ? await handleAccept(inviteId: inviteId)
            : await handleReject(inviteId: inviteId)

        isResponding = false
        return success
    }

    // MARK: - Private: Accept Flow

    private func handleAccept(inviteId: String) async -> Bool {
        do {
            try await invitationRepository.acceptInviteRPC(inviteId: inviteId)
            withAnimation(.easeInOut) {
                self.pendingInvitations.removeAll { $0.id == inviteId }
            }
            self.successMessage = "Invitation accepted! You are now a mechanic."
            return true
        } catch {
            self.errorMessage = "Failed to accept invitation: \(error.localizedDescription)"
            print("[InvitationVM] handleAccept error: \(error)")
            return false
        }
    }

    // MARK: - Private: Reject Flow

    private func handleReject(inviteId: String) async -> Bool {
        do {
            try await invitationRepository.rejectInviteRPC(inviteId: inviteId)
            withAnimation(.easeInOut) {
                self.pendingInvitations.removeAll { $0.id == inviteId }
            }
            self.successMessage = "Invitation declined."
            return true
        } catch {
            self.errorMessage = "Failed to decline invitation: \(error.localizedDescription)"
            print("[InvitationVM] handleReject error: \(error)")
            return false
        }
    }
}
