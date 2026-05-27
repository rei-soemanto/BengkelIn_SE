//
//  ServiceRequestRepository.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class ServiceRequestRepository {
    func insertRequest(_ payload: ServiceRequestInsert) async throws -> ServiceRequest {
        return try await supabase.from("service_requests")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchByCustomer(customerId: String) async throws -> [ServiceRequest] {
        return try await supabase.from("service_requests")
            .select()
            .eq("customer_id", value: customerId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchActiveByMechanic(mechanicId: String) async throws -> [ServiceRequest] {
        return try await supabase.from("service_requests")
            .select()
            .eq("mechanic_id", value: mechanicId)
            .in("status", values: [
                ServiceRequestStatus.accepted.rawValue,
                ServiceRequestStatus.inProgress.rawValue
            ])
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Pending + accepted + in-progress requests for a bengkel — used for incoming/active job lists.
    func fetchOpenByBengkel(bengkelId: String) async throws -> [ServiceRequest] {
        return try await supabase.from("service_requests")
            .select()
            .eq("bengkel_id", value: bengkelId)
            .in("status", values: [
                ServiceRequestStatus.pending.rawValue,
                ServiceRequestStatus.accepted.rawValue,
                ServiceRequestStatus.inProgress.rawValue
            ])
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Completed requests for a bengkel from the given ISO-8601 timestamp onwards.
    func fetchCompletedSince(bengkelId: String, sinceIso: String) async throws -> [ServiceRequest] {
        return try await supabase.from("service_requests")
            .select()
            .eq("bengkel_id", value: bengkelId)
            .eq("status", value: ServiceRequestStatus.completed.rawValue)
            .gte("updated_at", value: sinceIso)
            .execute()
            .value
    }

    func updateStatus(requestId: String, payload: ServiceRequestStatusUpdate) async throws {
        try await supabase.from("service_requests")
            .update(payload)
            .eq("id", value: requestId)
            .execute()
    }
}
