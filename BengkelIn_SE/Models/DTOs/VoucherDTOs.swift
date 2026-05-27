//
//  VoucherDTOs.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

// Used by VoucherRepository to create a promo
struct VoucherInsertPayload: Encodable {
    let code: String
    let title: String
    let discountAmount: Double
    let validUntil: String
    let providerUid: String

    enum CodingKeys: String, CodingKey {
        case code, title
        case discountAmount = "discount_amount"
        case validUntil     = "valid_until"
        case providerUid    = "provider_uid"
    }
}

// Used by VoucherRepository to insert a row in `user_vouchers` (claim)
struct UserVoucherInsert: Encodable {
    let userId: String
    let voucherId: String
    let isUsed: Bool

    enum CodingKeys: String, CodingKey {
        case userId    = "user_id"
        case voucherId = "voucher_id"
        case isUsed    = "is_used"
    }
}
