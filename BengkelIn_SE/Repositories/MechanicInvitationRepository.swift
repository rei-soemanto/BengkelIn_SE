//
//  MechanicInvitationRepository.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class MechanicInvitationRepository {
    /// Pending invitations for the given mechanic (with joined bengkel name).
    func fetchPendingForMechanic(mechanicId: String) async throws -> [MechanicInvitationDisplay] {
        return try await supabase
            .from("mechanic_invitations")
            .select("*, bengkels(name)")
            .eq("mechanic_id", value: mechanicId)
            .eq("status", value: InvitationStatus.pending.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// All invitations sent by a bengkel (provider dashboard).
    func fetchSentByBengkel(bengkelId: String) async throws -> [MechanicInvitation] {
        return try await supabase
            .from("mechanic_invitations")
            .select()
            .eq("bengkel_id", value: bengkelId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Existing pending invitations for a (bengkel, mechanic) pair — used to detect duplicates.
    func fetchPending(bengkelId: String, mechanicId: String) async throws -> [MechanicInvitation] {
        return try await supabase
            .from("mechanic_invitations")
            .select()
            .eq("bengkel_id", value: bengkelId)
            .eq("mechanic_id", value: mechanicId)
            .eq("status", value: InvitationStatus.pending.rawValue)
            .execute()
            .value
    }

    func insertInvitation(_ payload: MechanicInvitationInsert) async throws {
        try await supabase.from("mechanic_invitations")
            .insert(payload)
            .execute()
    }

    /// Calls the secure RPC `accept_mechanic_invite` (handles status + role + roster).
    func acceptInviteRPC(inviteId: String) async throws {
        try await supabase
            .rpc("accept_mechanic_invite", params: ["invite_id": inviteId])
            .execute()
    }

    /// Calls the secure RPC `reject_mechanic_invite`.
    func rejectInviteRPC(inviteId: String) async throws {
        try await supabase
            .rpc("reject_mechanic_invite", params: ["invite_id": inviteId])
            .execute()
    }
}
