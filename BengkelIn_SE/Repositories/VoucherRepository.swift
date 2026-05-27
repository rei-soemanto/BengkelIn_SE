//
//  VoucherRepository.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class VoucherRepository {
    /// Fetches all vouchers that are still valid (valid_until >= now).
    func fetchAvailableVouchers(nowIso: String) async throws -> [Voucher] {
        return try await supabase.from("vouchers")
            .select()
            .gte("valid_until", value: nowIso)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchVoucher(id: String) async throws -> Voucher {
        return try await supabase.from("vouchers")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchVouchersByCode(_ code: String) async throws -> [Voucher] {
        return try await supabase.from("vouchers")
            .select()
            .eq("code", value: code)
            .execute()
            .value
    }

    func fetchProviderVouchers(providerUid: String) async throws -> [Voucher] {
        return try await supabase.from("vouchers")
            .select()
            .eq("provider_uid", value: providerUid)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func insertVoucher(_ payload: VoucherInsertPayload) async throws {
        try await supabase.from("vouchers")
            .insert(payload)
            .execute()
    }

    /// Fetches the user's unused, claimed vouchers (with embedded voucher details).
    func fetchWallet(userId: String) async throws -> [UserVoucher] {
        return try await supabase.from("user_vouchers")
            .select("*, vouchers(*)")
            .eq("user_id", value: userId)
            .eq("is_used", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func insertUserVoucher(_ payload: UserVoucherInsert) async throws {
        try await supabase.from("user_vouchers")
            .insert(payload)
            .execute()
    }
}
