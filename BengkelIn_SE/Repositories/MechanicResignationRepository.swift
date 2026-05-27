//
//  MechanicResignationRepository.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class MechanicResignationRepository {
    func insertResignation(_ payload: MechanicResignationInsert) async throws {
        try await supabase.from("mechanic_resignations")
            .insert(payload)
            .execute()
    }

    /// Pending resignations targeting the given bengkel (joined with the resigning user's name).
    func fetchPendingForBengkel(bengkelId: String) async throws -> [MechanicResignation] {
        return try await supabase
            .from("mechanic_resignations")
            .select("*, users(name)")
            .eq("bengkel_id", value: bengkelId)
            .eq("status", value: "pending")
            .execute()
            .value
    }

    /// Calls the secure RPC `approve_mechanic_resignation`.
    func approveResignationRPC(resignationId: String) async throws {
        try await supabase
            .rpc("approve_mechanic_resignation", params: ["resignation_id": resignationId])
            .execute()
    }
}
