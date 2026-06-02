//
//  MechanicRepository.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import Foundation
import Supabase

// Roster CRUD over mechanic_registrations. All writes go through SECURITY DEFINER RPCs
// (the table itself only exposes SELECT via RLS), so this repository is thin.
class MechanicRepository {

    // MARK: Provider side

    func fetchRoster() async throws -> [RosterMember] {
        return try await supabase.rpc("bengkel_roster")
            .execute()
            .value
    }

    func inviteMechanic(email: String) async throws {
        try await supabase.rpc(
            "invite_mechanic",
            params: InviteMechanicParams(p_email: email)
        )
        .execute()
    }

    func removeMechanic(registrationId: String) async throws {
        try await supabase.rpc(
            "remove_mechanic",
            params: RemoveMechanicParams(p_registration_id: registrationId)
        )
        .execute()
    }

    // Accepted mechanics for the caller's bengkel — used by the assignment picker.
    func fetchAvailableMechanics() async throws -> [AvailableMechanic] {
        return try await supabase.rpc("available_mechanics")
            .execute()
            .value
    }

    // MARK: Mechanic side

    func fetchMyInvites() async throws -> [MechanicInvite] {
        return try await supabase.rpc("my_mechanic_invites")
            .execute()
            .value
    }

    func respondToInvite(registrationId: String, accept: Bool) async throws {
        try await supabase.rpc(
            "respond_mechanic_invite",
            params: RespondInviteParams(p_registration_id: registrationId, p_accept: accept)
        )
        .execute()
    }
}
