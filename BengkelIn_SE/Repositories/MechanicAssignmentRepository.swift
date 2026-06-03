//
//  MechanicAssignmentRepository.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Foundation
import Supabase

// Dispatch data access (Eugene's slice). Assignment goes through the assign_mechanic RPC;
// the mechanic's own job feed is a direct SELECT permitted by the "Mechanics can view their
// assigned requests" RLS policy.
class MechanicAssignmentRepository {

    // Dispatch the order to a roster mechanic (bengkel "Self" was removed). Returns the
    // updated order row. The RPC enforces roster membership, the busy guard, and reassignment.
    @discardableResult
    func assignMechanic(requestId: String, mechanicId: String) async throws -> NearbyOrder {
        return try await supabase.rpc(
            "assign_mechanic",
            params: AssignMechanicParams(p_request_id: requestId, p_mechanic_id: mechanicId)
        )
        .single()
        .execute()
        .value
    }

    // Active jobs assigned to this mechanic (status stays 'accepted' while being worked).
    func fetchAssignedJobs(mechanicId: String) async throws -> [NearbyOrder] {
        return try await supabase.from("service_requests")
            .select()
            .eq("mechanic_id", value: mechanicId)
            .eq("status", value: "accepted")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
}
