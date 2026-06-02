//
//  WithdrawalRepository.swift
//  BengkelIn_SE
//
//  Ported from MbengkelIn (Eugene's wallet feature).
//

import Foundation
import Supabase

class WithdrawalRepository {
    func fetchWithdrawals(userId: String) async throws -> [Withdrawal] {
        return try await supabase.from("withdrawals")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // Atomic available-balance check + pending withdrawal insert (server-side RPC).
    func requestWithdrawal(amount: Double) async throws {
        try await supabase
            .rpc("request_withdrawal", params: RequestWithdrawalParams(p_amount: amount))
            .execute()
    }
}
