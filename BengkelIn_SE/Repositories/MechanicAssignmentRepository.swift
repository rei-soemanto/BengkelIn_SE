//
//  MechanicAssignmentRepository.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Foundation
import Supabase

class MechanicAssignmentRepository {

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
