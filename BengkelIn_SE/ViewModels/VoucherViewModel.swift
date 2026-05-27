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

@MainActor
class VoucherViewModel: ObservableObject {

    // MARK: - Published State

    @Published var availableVouchers: [Voucher] = []
    @Published var myWallet: [UserVoucher] = []
    @Published var bengkelNames: [String: String] = [:]

    @Published var isLoading = false
    @Published var isClaiming = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let authService = AuthService()
    private let voucherRepository = VoucherRepository()
    private let bengkelRepository = BengkelRepository()

    init() {}

    // MARK: - 1. Fetch Available Vouchers

    func fetchAvailableVouchers() async {
        isLoading = true
        errorMessage = nil

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let nowStr = isoFormatter.string(from: Date())

        do {
            let vouchers = try await voucherRepository.fetchAvailableVouchers(nowIso: nowStr)
            self.availableVouchers = vouchers
        } catch {
            self.errorMessage = "Failed to load vouchers: \(error.localizedDescription)"
            print("[VoucherVM] fetchAvailableVouchers error: \(error)")
        }

        isLoading = false
    }

    // MARK: - 2. Fetch My Wallet

    func fetchMyWallet(selectedBengkelProviderUid: String? = nil) async {
        isLoading = true
        errorMessage = nil

        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "You must be logged in to view your vouchers."
            isLoading = false
            return
        }
        let uid = session.user.id.uuidString.lowercased()

        do {
            var wallet = try await voucherRepository.fetchWallet(userId: uid)

            // Filter out promos that belong to a different provider when scoped to a workshop
            if let targetUid = selectedBengkelProviderUid {
                wallet = wallet.filter { item in
                    guard let pUid = item.vouchers?.providerUid else { return true } // global promo
                    return pUid == targetUid                                          // shop-specific
                }
            }

            self.myWallet = wallet
        } catch {
            self.errorMessage = "Failed to load your vouchers: \(error.localizedDescription)"
            print("[VoucherVM] fetchMyWallet error: \(error)")
        }

        isLoading = false
    }

    // MARK: - 3. Claim Voucher (by id)

    func claimVoucher(voucherId: String) async -> Bool {
        isClaiming = true
        errorMessage = nil
        successMessage = nil

        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "You must be logged in to claim a voucher."
            isClaiming = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()

        if myWallet.contains(where: { $0.voucherId == voucherId }) {
            self.errorMessage = "You have already claimed this voucher."
            isClaiming = false
            return false
        }

        let payload = UserVoucherInsert(userId: uid, voucherId: voucherId, isUsed: false)

        do {
            try await voucherRepository.insertUserVoucher(payload)
            self.successMessage = "Voucher claimed successfully!"
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

    // MARK: - 3.5 Claim by Code (Manual Entry)

    func claimByCode(code: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else {
            self.errorMessage = "Please enter a promo code."
            isLoading = false
            return
        }

        guard let session = try? await authService.getCurrentSession() else {
            self.errorMessage = "You must be logged in to claim a voucher."
            isLoading = false
            return
        }
        let uid = session.user.id.uuidString.lowercased()

        do {
            let vouchers = try await voucherRepository.fetchVouchersByCode(normalized)

            guard let voucher = vouchers.first, let vId = voucher.id else {
                self.errorMessage = "Invalid Code: No voucher found."
                isLoading = false
                return
            }

            if let validUntil = voucher.validUntil, validUntil < Date() {
                self.errorMessage = "This promo code has expired."
                isLoading = false
                return
            }

            if myWallet.contains(where: { $0.voucherId == vId }) {
                self.errorMessage = "You have already claimed this promo."
                isLoading = false
                return
            }

            let payload = UserVoucherInsert(userId: uid, voucherId: vId, isUsed: false)
            try await voucherRepository.insertUserVoucher(payload)

            self.successMessage = "Promo applied successfully!"
            await fetchMyWallet()
        } catch {
            self.errorMessage = "Failed to apply code: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 4. Find Voucher by Code (from already-loaded list)

    func findVoucher(byCode code: String) -> Voucher? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return availableVouchers.first { ($0.code ?? "").uppercased() == normalized }
    }

    // MARK: - 5. Helpers

    func isVoucherUsable(_ voucher: Voucher) -> Bool {
        guard let validUntil = voucher.validUntil else { return false }
        return Date() < validUntil
    }

    func isVoucherClaimed(_ voucher: Voucher) -> Bool {
        guard let voucherId = voucher.id else { return false }
        return myWallet.contains { $0.voucherId == voucherId }
    }

    func discountDisplayText(for voucher: Voucher) -> String {
        guard let amount = voucher.discountAmount else { return "Discount" }
        return "\(amount.toRupiah()) OFF"
    }

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

    // MARK: - Scope Fetching (bengkel name lookup, cached)

    func fetchBengkelName(providerUid: String) async {
        if bengkelNames[providerUid] != nil { return }
        do {
            let bengkel = try await bengkelRepository.fetchBengkel(providerUid: providerUid)
            self.bengkelNames[providerUid] = bengkel.name
        } catch {
            print("Failed to fetch bengkel name for \(providerUid): \(error)")
        }
    }
}
