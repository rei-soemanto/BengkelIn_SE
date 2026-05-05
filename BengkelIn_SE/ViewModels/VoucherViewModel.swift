//
//  VoucherViewModel.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//

import SwiftUI
import Combine

// MARK: - Validation Errors

enum VoucherValidationError: String, CaseIterable {
    case expired = "This voucher has expired."
    case notYetActive = "This voucher is not yet active."
    case deactivated = "This voucher is no longer available."
    case usageLimitReached = "This voucher has reached its usage limit."
    case alreadyUsedByUser = "You have already used this voucher."
    case belowMinimumOrder = "Your order does not meet the minimum spend."
    case notApplicableToService = "This voucher cannot be applied to this service."
    case notStackable = "This voucher cannot be combined with other discounts."
    case notEligible = "You are not eligible for this voucher."
    case wrongBengkel = "This voucher is only valid at a different workshop."
    case codeNotFound = "Invalid voucher code. Please check and try again."
}

// MARK: - VoucherViewModel

@MainActor
class VoucherViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var availableVouchers: [Voucher] = []
    @Published var userClaims: [VoucherClaim] = []
    @Published var bengkelVouchers: [Voucher] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var validationError: VoucherValidationError?
    
    // MARK: - Mock Data Initialization
    
    init() {
        loadMockVouchers()
        loadMockClaims()
    }
    
    private func loadMockVouchers() {
        let now = Date()
        let calendar = Calendar.current
        
        availableVouchers = [
            // 1. Active percentage voucher with max cap
            Voucher(
                id: "voucher-001",
                code: "DARURAT20",
                discountType: .percentage,
                discountValue: 20,
                maximumDiscountAmount: 100_000,
                minimumOrderValue: 50_000,
                scope: .platformWide,
                issuedByBengkelId: nil,
                applicableServiceIds: nil,
                globalUsageLimit: 500,
                perUserUsageLimit: 1,
                currentUsageCount: 127,
                startDate: calendar.date(byAdding: .day, value: -10, to: now)!,
                expiryDate: calendar.date(byAdding: .day, value: 20, to: now)!,
                isStackable: false,
                isActive: true,
                userEligibility: .allUsers,
                createdAt: calendar.date(byAdding: .day, value: -10, to: now)!,
                createdByUserId: "admin-001"
            ),
            
            // 2. Fixed discount — bengkel specific
            Voucher(
                id: "voucher-002",
                code: "BENGKEL50K",
                discountType: .fixed,
                discountValue: 50_000,
                maximumDiscountAmount: nil,
                minimumOrderValue: 100_000,
                scope: .bengkelSpecific,
                issuedByBengkelId: "bengkel-001",
                applicableServiceIds: nil,
                globalUsageLimit: 100,
                perUserUsageLimit: 1,
                currentUsageCount: 43,
                startDate: calendar.date(byAdding: .day, value: -5, to: now)!,
                expiryDate: calendar.date(byAdding: .day, value: 25, to: now)!,
                isStackable: false,
                isActive: true,
                userEligibility: .allUsers,
                createdAt: calendar.date(byAdding: .day, value: -5, to: now)!,
                createdByUserId: "provider-001"
            ),
            
            // 3. New user exclusive voucher
            Voucher(
                id: "voucher-003",
                code: "WELCOME30",
                discountType: .percentage,
                discountValue: 30,
                maximumDiscountAmount: 75_000,
                minimumOrderValue: nil,
                scope: .platformWide,
                issuedByBengkelId: nil,
                applicableServiceIds: nil,
                globalUsageLimit: nil,
                perUserUsageLimit: 1,
                currentUsageCount: 891,
                startDate: calendar.date(byAdding: .month, value: -1, to: now)!,
                expiryDate: calendar.date(byAdding: .month, value: 2, to: now)!,
                isStackable: false,
                isActive: true,
                userEligibility: .newUsersOnly,
                createdAt: calendar.date(byAdding: .month, value: -1, to: now)!,
                createdByUserId: "admin-001"
            ),
            
            // 4. Expired voucher (for testing expiry state in UI)
            Voucher(
                id: "voucher-004",
                code: "EXPIRED10",
                discountType: .percentage,
                discountValue: 10,
                maximumDiscountAmount: 30_000,
                minimumOrderValue: nil,
                scope: .platformWide,
                issuedByBengkelId: nil,
                applicableServiceIds: nil,
                globalUsageLimit: 200,
                perUserUsageLimit: 1,
                currentUsageCount: 200,
                startDate: calendar.date(byAdding: .month, value: -2, to: now)!,
                expiryDate: calendar.date(byAdding: .day, value: -1, to: now)!,
                isStackable: false,
                isActive: true,
                userEligibility: .allUsers,
                createdAt: calendar.date(byAdding: .month, value: -2, to: now)!,
                createdByUserId: "admin-001"
            ),
            
            // 5. Stackable small discount (for testing stack logic)
            Voucher(
                id: "voucher-005",
                code: "EXTRA5K",
                discountType: .fixed,
                discountValue: 5_000,
                maximumDiscountAmount: nil,
                minimumOrderValue: nil,
                scope: .platformWide,
                issuedByBengkelId: nil,
                applicableServiceIds: nil,
                globalUsageLimit: nil,
                perUserUsageLimit: 3,
                currentUsageCount: 1_204,
                startDate: calendar.date(byAdding: .day, value: -15, to: now)!,
                expiryDate: calendar.date(byAdding: .month, value: 1, to: now)!,
                isStackable: true,
                isActive: true,
                userEligibility: .returningOnly,
                createdAt: calendar.date(byAdding: .day, value: -15, to: now)!,
                createdByUserId: "admin-001"
            )
        ]
        
        // Bengkel's own vouchers (same data filtered, simulating provider view)
        bengkelVouchers = availableVouchers.filter { $0.issuedByBengkelId == "bengkel-001" }
    }
    
    private func loadMockClaims() {
        let now = Date()
        let calendar = Calendar.current
        
        userClaims = [
            VoucherClaim(
                id: "claim-001",
                voucherId: "voucher-001",
                userId: "mock-user-001",
                claimedAt: calendar.date(byAdding: .day, value: -2, to: now)!,
                appliedToOrderId: nil,
                usedAt: nil,
                discountAmountApplied: nil,
                status: .claimed
            )
        ]
    }
    
    // MARK: - Validation Engine
    
    /// The core validation function. Returns nil if valid, or a specific error.
    /// This exact logic will be replicated server-side during backend migration.
    func validateVoucher(
        _ voucher: Voucher,
        forUserId userId: String,
        orderTotal: Double,
        serviceId: String,
        bengkelId: String,
        existingVouchersOnOrder: [Voucher],
        userOrderCount: Int
    ) -> VoucherValidationError? {
        
        // 1. Active check
        guard voucher.isActive else { return .deactivated }
        
        // 2. Time window
        let now = Date()
        guard now >= voucher.startDate else { return .notYetActive }
        guard now < voucher.expiryDate else { return .expired }
        
        // 3. Global usage limit
        if let limit = voucher.globalUsageLimit,
           voucher.currentUsageCount >= limit {
            return .usageLimitReached
        }
        
        // 4. Per-user usage limit
        let userRedemptions = userClaims.filter {
            $0.voucherId == voucher.id && ($0.status == .redeemed || $0.status == .applied)
        }.count
        if userRedemptions >= voucher.perUserUsageLimit {
            return .alreadyUsedByUser
        }
        
        // 5. Minimum order value
        if let min = voucher.minimumOrderValue, orderTotal < min {
            return .belowMinimumOrder
        }
        
        // 6. Service applicability
        if let applicableIds = voucher.applicableServiceIds,
           !applicableIds.contains(serviceId) {
            return .notApplicableToService
        }
        
        // 7. Bengkel scope
        if voucher.scope == .bengkelSpecific,
           voucher.issuedByBengkelId != bengkelId {
            return .wrongBengkel
        }
        
        // 8. Stackability
        if !existingVouchersOnOrder.isEmpty {
            let hasNonStackable = existingVouchersOnOrder.contains { !$0.isStackable }
            if hasNonStackable || !voucher.isStackable {
                return .notStackable
            }
        }
        
        // 9. User eligibility
        switch voucher.userEligibility {
        case .newUsersOnly:
            if userOrderCount > 0 { return .notEligible }
        case .returningOnly:
            if userOrderCount == 0 { return .notEligible }
        case .allUsers:
            break
        }
        
        return nil // ✅ Valid
    }
    
    // MARK: - Discount Calculation
    
    /// Calculates the actual discount amount, applying max cap and floor-at-zero.
    /// This logic must be identical to the server-side calculation on migration.
    func calculateDiscount(voucher: Voucher, orderTotal: Double) -> Double {
        let rawDiscount: Double
        
        switch voucher.discountType {
        case .percentage:
            rawDiscount = orderTotal * (voucher.discountValue / 100.0)
        case .fixed:
            rawDiscount = voucher.discountValue
        }
        
        // Apply maximum cap (for percentage discounts)
        var finalDiscount = rawDiscount
        if let maxCap = voucher.maximumDiscountAmount {
            finalDiscount = min(rawDiscount, maxCap)
        }
        
        // Never let discount exceed order total (prevent negative)
        finalDiscount = min(finalDiscount, orderTotal)
        
        return finalDiscount
    }
    
    // MARK: - User Actions (Stubs)
    
    /// Looks up a voucher by its code string.
    func findVoucher(byCode code: String) -> Voucher? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return availableVouchers.first { $0.code.uppercased() == normalized }
    }
    
    /// Claims a voucher for the user — adds to their "My Vouchers".
    func claimVoucher(voucherId: String, userId: String) {
        print("[VoucherVM] claimVoucher called — voucher: \(voucherId), user: \(userId)")
        
        // Check if already claimed
        let alreadyClaimed = userClaims.contains {
            $0.voucherId == voucherId && $0.userId == userId && $0.status == .claimed
        }
        
        guard !alreadyClaimed else {
            errorMessage = "You have already claimed this voucher."
            return
        }
        
        let claim = VoucherClaim(
            id: UUID().uuidString,
            voucherId: voucherId,
            userId: userId,
            claimedAt: Date(),
            appliedToOrderId: nil,
            usedAt: nil,
            discountAmountApplied: nil,
            status: .claimed
        )
        
        withAnimation(.easeInOut) {
            userClaims.append(claim)
        }
        
        successMessage = "Voucher claimed successfully!"
        print("[VoucherVM] Claim created: \(claim.id)")
    }
    
    /// Applies a voucher to an order (validates first).
    func applyVoucher(
        voucherId: String,
        userId: String,
        orderTotal: Double,
        serviceId: String,
        bengkelId: String,
        existingVouchersOnOrder: [Voucher],
        userOrderCount: Int
    ) -> Double? {
        validationError = nil
        errorMessage = nil
        
        guard let voucher = availableVouchers.first(where: { $0.id == voucherId }) else {
            validationError = .codeNotFound
            return nil
        }
        
        // Run the full validation engine
        if let error = validateVoucher(
            voucher,
            forUserId: userId,
            orderTotal: orderTotal,
            serviceId: serviceId,
            bengkelId: bengkelId,
            existingVouchersOnOrder: existingVouchersOnOrder,
            userOrderCount: userOrderCount
        ) {
            validationError = error
            errorMessage = error.rawValue
            print("[VoucherVM] Validation failed: \(error.rawValue)")
            return nil
        }
        
        // Calculate discount
        let discount = calculateDiscount(voucher: voucher, orderTotal: orderTotal)
        
        // Update claim status
        if let claimIndex = userClaims.firstIndex(where: {
            $0.voucherId == voucherId && $0.userId == userId && $0.status == .claimed
        }) {
            withAnimation(.easeInOut) {
                userClaims[claimIndex].status = .applied
                userClaims[claimIndex].discountAmountApplied = discount
            }
        }
        
        // Increment usage count (mock)
        if let voucherIndex = availableVouchers.firstIndex(where: { $0.id == voucherId }) {
            availableVouchers[voucherIndex].currentUsageCount += 1
        }
        
        successMessage = "Voucher applied! You save \(discount.toRupiah())"
        print("[VoucherVM] Voucher \(voucherId) applied. Discount: \(discount.toRupiah())")
        return discount
    }
    
    // MARK: - Bengkel / Provider Actions (Stubs)
    
    /// Provider creates a new voucher for their bengkel.
    func createVoucher(
        code: String,
        discountType: DiscountType,
        discountValue: Double,
        maxDiscount: Double?,
        minOrder: Double?,
        globalLimit: Int?,
        perUserLimit: Int,
        startDate: Date,
        expiryDate: Date,
        isStackable: Bool,
        eligibility: UserEligibility,
        bengkelId: String,
        createdByUserId: String
    ) {
        print("[VoucherVM] createVoucher called — code: \(code)")
        
        // Check code uniqueness
        let codeExists = availableVouchers.contains {
            $0.code.uppercased() == code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        
        guard !codeExists else {
            errorMessage = "A voucher with this code already exists."
            return
        }
        
        let voucher = Voucher(
            id: UUID().uuidString,
            code: code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
            discountType: discountType,
            discountValue: discountValue,
            maximumDiscountAmount: maxDiscount,
            minimumOrderValue: minOrder,
            scope: .bengkelSpecific,
            issuedByBengkelId: bengkelId,
            applicableServiceIds: nil,
            globalUsageLimit: globalLimit,
            perUserUsageLimit: perUserLimit,
            currentUsageCount: 0,
            startDate: startDate,
            expiryDate: expiryDate,
            isStackable: isStackable,
            isActive: true,
            userEligibility: eligibility,
            createdAt: Date(),
            createdByUserId: createdByUserId
        )
        
        withAnimation(.easeInOut) {
            availableVouchers.append(voucher)
            bengkelVouchers.append(voucher)
        }
        
        successMessage = "Voucher \"\(voucher.code)\" created successfully!"
        print("[VoucherVM] Voucher created: \(voucher.id)")
    }
    
    /// Provider deactivates a voucher (soft delete — never hard delete).
    func deactivateVoucher(voucherId: String) {
        print("[VoucherVM] deactivateVoucher called — id: \(voucherId)")
        
        if let index = availableVouchers.firstIndex(where: { $0.id == voucherId }) {
            withAnimation(.easeInOut) {
                availableVouchers[index].isActive = false
            }
        }
        if let index = bengkelVouchers.firstIndex(where: { $0.id == voucherId }) {
            withAnimation(.easeInOut) {
                bengkelVouchers[index].isActive = false
            }
        }
        
        successMessage = "Voucher deactivated."
    }
    
    // MARK: - Helpers
    
    /// Returns the user's claimed (but not yet used) vouchers.
    var claimedVouchers: [Voucher] {
        let claimedIds = userClaims
            .filter { $0.status == .claimed }
            .map { $0.voucherId }
        return availableVouchers.filter { claimedIds.contains($0.id) }
    }
    
    /// Checks if a voucher is currently valid (not expired, active, within usage limits).
    func isVoucherUsable(_ voucher: Voucher) -> Bool {
        let now = Date()
        guard voucher.isActive else { return false }
        guard now >= voucher.startDate else { return false }
        guard now < voucher.expiryDate else { return false }
        if let limit = voucher.globalUsageLimit,
           voucher.currentUsageCount >= limit { return false }
        return true
    }
    
    /// Formats discount display text (e.g., "20% OFF" or "Rp 50.000 OFF").
    func discountDisplayText(for voucher: Voucher) -> String {
        switch voucher.discountType {
        case .percentage:
            let pct = Int(voucher.discountValue)
            if let cap = voucher.maximumDiscountAmount {
                return "\(pct)% OFF (max \(cap.toRupiah()))"
            }
            return "\(pct)% OFF"
        case .fixed:
            return "\(voucher.discountValue.toRupiah()) OFF"
        }
    }
}
