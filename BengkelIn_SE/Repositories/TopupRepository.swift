//
//  TopupRepository.swift
//  BengkelIn_SE
//
//  Ported from MbengkelIn (Eugene's wallet feature).
//

import Foundation
import Supabase

class TopupRepository {
    func fetchTopups(userId: String) async throws -> [Topup] {
        return try await supabase.from("topups")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
}
