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
// Handles: fetching pending invitations for the current mechanic user,
// accepting (with role + bengkel roster update), and rejecting invitations.

@MainActor
class InvitationViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var pendingInvitations: [MechanicInvitationDisplay] = []
    @Published var isLoading = false
    @Published var isResponding = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Fetch Pending Invitations
    
    /// Fetches all pending invitations for the currently authenticated user.
    /// Uses a joined select to pull the bengkel name for display.
    func fetchPendingInvitations() async {
        isLoading = true
        errorMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "You must be logged in."
            isLoading = false
            return
        }
        let uid = session.user.id.uuidString.lowercased()
        
        do {
            let invitations: [MechanicInvitationDisplay] = try await supabase
                .from("mechanic_invitations")
                .select("*, bengkels(name)")
                .eq("mechanic_id", value: uid)
                .eq("status", value: InvitationStatus.pending.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.pendingInvitations = invitations
        } catch {
            self.errorMessage = "Failed to load invitations: \(error.localizedDescription)"
            print("[InvitationVM] fetchPendingInvitations error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Respond to Invitation
    
    /// Responds to a mechanic invitation (accept or reject).
    ///
    /// **If Accept:**
    /// 1. Update invitation status → `accepted`
    /// 2. Update `users.role` → `MECHANIC`
    /// 3. Append user ID to `bengkels.mechanic_uids` array
    ///
    /// **If Reject:**
    /// 1. Update invitation status → `rejected`
    ///
    func respondToInvite(inviteId: String, accept: Bool) async -> Bool {
        isResponding = true
        errorMessage = nil
        successMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "You must be logged in."
            isResponding = false
            return false
        }
        
        let success: Bool
        if accept {
            success = await handleAccept(inviteId: inviteId)
        } else {
            success = await handleReject(inviteId: inviteId)
        }
        
        isResponding = false
        return success
    }
    
    // MARK: - Private: Accept Flow
    
    private func handleAccept(inviteId: String) async -> Bool {
        do {
            try await supabase.rpc("accept_mechanic_invite", params: ["invite_id": inviteId]).execute()
            
            // Remove from local list
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
            try await supabase.rpc("reject_mechanic_invite", params: ["invite_id": inviteId]).execute()
            
            // Remove from local list
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
