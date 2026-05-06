//
//  VoucherViewModel.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//  Migrated to live Supabase backend on 07/05/26.
//

import SwiftUI
import Combine
import Supabase

// MARK: - VoucherViewModel

@MainActor
class VoucherViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// All active vouchers available for claiming.
    @Published var availableVouchers: [Voucher] = []
    
    /// The current user's claimed vouchers (with nested voucher details).
    @Published var myWallet: [UserVoucher] = []
    
    @Published var isLoading = false
    @Published var isClaiming = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Initialization (no more mock data!)
    
    init() {
        // Data is fetched on-demand via .task {} in the View
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 1. Fetch Available Vouchers
    // ──────────────────────────────────────────────────────
    
    /// Fetches all vouchers from the `vouchers` table that are still valid.
    func fetchAvailableVouchers() async {
        isLoading = true
        errorMessage = nil
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let nowStr = isoFormatter.string(from: Date())
        
        do {
            let vouchers: [Voucher] = try await supabase.from("vouchers")
                .select()
                .gte("valid_until", value: nowStr)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.availableVouchers = vouchers
        } catch {
            self.errorMessage = "Failed to load vouchers: \(error.localizedDescription)"
            print("[VoucherVM] fetchAvailableVouchers error: \(error)")
        }
        
        isLoading = false
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 2. Fetch My Wallet (User's Claimed Vouchers)
    // ──────────────────────────────────────────────────────
    
    /// Fetches the authenticated user's voucher wallet from `user_vouchers`.
    /// Uses Supabase's foreign key join to embed the full voucher details.
    func fetchMyWallet(selectedBengkelProviderUid: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "You must be logged in to view your vouchers."
            isLoading = false
            return
        }
        let uid = session.user.id.uuidString.lowercased()
        
        do {
            var wallet: [UserVoucher] = try await supabase.from("user_vouchers")
                .select("*, vouchers(*)")
                .eq("user_id", value: uid)
                .eq("is_used", value: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Filter out promos that belong to a different provider
            if let targetUid = selectedBengkelProviderUid {
                wallet = wallet.filter { item in
                    guard let pUid = item.vouchers?.providerUid else { return true } // Global promo
                    return pUid == targetUid // Shop-specific promo
                }
            }
            
            self.myWallet = wallet
        } catch {
            self.errorMessage = "Failed to load your vouchers: \(error.localizedDescription)"
            print("[VoucherVM] fetchMyWallet error: \(error)")
        }
        
        isLoading = false
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 3. Claim Voucher
    // ──────────────────────────────────────────────────────
    
    /// Claims a voucher by inserting a row into `user_vouchers`.
    /// - Parameter voucherId: The UUID of the voucher to claim.
    /// - Returns: `true` on success.
    func claimVoucher(voucherId: String) async -> Bool {
        isClaiming = true
        errorMessage = nil
        successMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "You must be logged in to claim a voucher."
            isClaiming = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        
        // Check if already claimed
        let alreadyClaimed = myWallet.contains { $0.voucherId == voucherId }
        if alreadyClaimed {
            self.errorMessage = "You have already claimed this voucher."
            isClaiming = false
            return false
        }
        
        let insertPayload = UserVoucherInsert(
            userId: uid,
            voucherId: voucherId,
            isUsed: false
        )
        
        do {
            try await supabase.from("user_vouchers")
                .insert(insertPayload)
                .execute()
            
            self.successMessage = "Voucher claimed successfully!"
            
            // Refresh wallet to pick up the new claim with joined data
            await fetchMyWallet()
            
            isClaiming = false
            return true
        } catch {
            self.errorMessage = "Failed to claim voucher: \(error.localizedDescription)"
            print("[VoucherVM] claimVoucher error: \(error)")
            isClaiming = false
            return false
        }
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 3.5 Claim by Code (Manual Entry)
    // ──────────────────────────────────────────────────────
    
    func claimByCode(code: String) async {
        isLoading = true // Use loading state to prevent double-clicks
        errorMessage = nil
        successMessage = nil
        
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else {
            self.errorMessage = "Please enter a promo code."
            isLoading = false
            return
        }
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "You must be logged in to claim a voucher."
            isLoading = false
            return
        }
        let uid = session.user.id.uuidString.lowercased()
        
        do {
            // Find the voucher in the DB
            let vouchers: [Voucher] = try await supabase.from("vouchers")
                .select()
                .eq("code", value: normalized)
                .execute()
                .value
            
            guard let voucher = vouchers.first, let vId = voucher.id else {
                self.errorMessage = "Invalid Code: No voucher found."
                isLoading = false
                return
            }
            
            // Check if expired
            if let validUntil = voucher.validUntil, validUntil < Date() {
                self.errorMessage = "This promo code has expired."
                isLoading = false
                return
            }
            
            // Check if already claimed
            if myWallet.contains(where: { $0.voucherId == vId }) {
                self.errorMessage = "You have already claimed this promo."
                isLoading = false
                return
            }
            
            // Claim it
            let payload = UserVoucherInsert(userId: uid, voucherId: vId, isUsed: false)
            try await supabase.from("user_vouchers").insert(payload).execute()
            
            self.successMessage = "Promo applied successfully!"
            await fetchMyWallet()
            
        } catch {
            self.errorMessage = "Failed to apply code: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 4. Find Voucher by Code
    
    /// Looks up a voucher by code from the already-fetched list.
    func findVoucher(byCode code: String) -> Voucher? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return availableVouchers.first { ($0.code ?? "").uppercased() == normalized }
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 5. Helpers
    // ──────────────────────────────────────────────────────
    
    /// Checks if a voucher is still valid (not expired).
    func isVoucherUsable(_ voucher: Voucher) -> Bool {
        guard let validUntil = voucher.validUntil else { return false }
        return Date() < validUntil
    }
    
    /// Checks if a voucher has already been claimed by the current user.
    func isVoucherClaimed(_ voucher: Voucher) -> Bool {
        guard let voucherId = voucher.id else { return false }
        return myWallet.contains { $0.voucherId == voucherId }
    }
    
    /// Returns a display-friendly discount text.
    func discountDisplayText(for voucher: Voucher) -> String {
        guard let amount = voucher.discountAmount else { return "Discount" }
        return "\(amount.toRupiah()) OFF"
    }
    
    /// Returns user-friendly expiry text.
    func expiryText(for voucher: Voucher) -> String {
        guard let validUntil = voucher.validUntil else { return "No expiry" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: validUntil).day ?? 0
        if days < 0 { return "Expired" }
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }
    
    func isExpiringSoon(_ voucher: Voucher) -> Bool {
        guard let validUntil = voucher.validUntil else { return false }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: validUntil).day ?? 0
        return days >= 0 && days <= 3
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - Scope Fetching
    // ──────────────────────────────────────────────────────
    
    @Published var bengkelNames: [String: String] = [:]
    
    func fetchBengkelName(providerUid: String) async {
        if bengkelNames[providerUid] != nil { return }
        do {
            let bengkel: Bengkel = try await supabase.from("bengkels")
                .select()
                .eq("provider_uid", value: providerUid)
                .single()
                .execute()
                .value
            
            // Update on main thread
            self.bengkelNames[providerUid] = bengkel.name
        } catch {
            print("Failed to fetch bengkel name for \(providerUid): \(error)")
        }
    }
}
