//
//  BengkelRepository.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class BengkelRepository {
    func fetchBengkel(providerUid: String) async throws -> Bengkel {
        return try await supabase.from("bengkels")
            .select()
            .eq("provider_uid", value: providerUid)
            .single()
            .execute()
            .value
    }

    func fetchBengkel(bengkelId: String) async throws -> Bengkel {
        return try await supabase.from("bengkels")
            .select()
            .eq("id", value: bengkelId)
            .single()
            .execute()
            .value
    }

    func fetchVerifiedBengkels() async throws -> [Bengkel] {
        return try await supabase.from("bengkels")
            .select()
            .eq("status", value: "Verified")
            .order("average_rating", ascending: false)
            .execute()
            .value
    }

    func insertBengkel(_ bengkel: Bengkel) async throws {
        try await supabase.from("bengkels")
            .insert(bengkel)
            .execute()
    }

    func updateBengkel(bengkelId: String, payload: BengkelUpdatePayload) async throws {
        try await supabase.from("bengkels")
            .update(payload)
            .eq("id", value: bengkelId)
            .execute()
    }

    /// Persists the full Bengkel record. Used when offered_services / mechanic_uids change
    /// and the call site already has the updated full Bengkel in memory.
    func saveBengkel(bengkelId: String, bengkel: Bengkel) async throws {
        try await supabase.from("bengkels")
            .update(bengkel)
            .eq("id", value: bengkelId)
            .execute()
    }

    func deleteBengkel(bengkelId: String) async throws {
        try await supabase.from("bengkels")
            .delete()
            .eq("id", value: bengkelId)
            .execute()
    }

    /// Counts the number of bengkels owned by the given provider — used to detect provider role.
    func countByProvider(uid: String) async throws -> Int {
        return try await supabase.from("bengkels")
            .select("id", head: true, count: .exact)
            .eq("provider_uid", value: uid)
            .execute()
            .count ?? 0
    }

    /// Fetches the caller's bengkel via RPC `get_my_bengkel` (used by mechanic-side flows where
    /// the caller is not the provider and direct SELECT may be restricted by RLS).
    func fetchMyBengkelRPC() async throws -> Bengkel {
        return try await supabase
            .rpc("get_my_bengkel")
            .single()
            .execute()
            .value
    }
}
