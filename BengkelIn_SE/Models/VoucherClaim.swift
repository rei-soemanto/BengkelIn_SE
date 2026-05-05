//
//  VoucherClaim.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//

import Foundation

// MARK: - Claim Status

enum ClaimStatus: String, Codable, CaseIterable {
    case claimed     // User saved the voucher to "My Vouchers"
    case applied     // User attached it to an order (order not yet completed)
    case redeemed    // Order completed, discount was applied
    case expired     // Voucher expired while claimed but unused
    case revoked     // Manually revoked by bengkel/admin
}

// MARK: - VoucherClaim Model

struct VoucherClaim: Codable, Identifiable {
    let id: String
    let voucherId: String
    let userId: String
    let claimedAt: Date
    var appliedToOrderId: String?
    var usedAt: Date?
    var discountAmountApplied: Double?
    var status: ClaimStatus

    enum CodingKeys: String, CodingKey {
        case id
        case voucherId = "voucher_id"
        case userId = "user_id"
        case claimedAt = "claimed_at"
        case appliedToOrderId = "applied_to_order_id"
        case usedAt = "used_at"
        case discountAmountApplied = "discount_amount_applied"
        case status
    }
}
