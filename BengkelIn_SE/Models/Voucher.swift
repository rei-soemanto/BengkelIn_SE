//
//  Voucher.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//  Migrated to live Supabase backend on 07/05/26.
//

import Foundation

// MARK: - Voucher Model (maps to `vouchers` table)

struct Voucher: Codable, Identifiable {
    var id: String?
    var code: String?
    var title: String?
    var discountAmount: Double?
    var validUntil: Date?
    var createdAt: Date?
    var providerUid: String?

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case title
        case discountAmount = "discount_amount"
        case validUntil     = "valid_until"
        case createdAt      = "created_at"
        case providerUid    = "provider_uid"
    }
}

// MARK: - UserVoucher Model (maps to `user_vouchers` table)
// Uses Supabase foreign key join to embed the related Voucher.

struct UserVoucher: Codable, Identifiable {
    var id: String?
    var userId: String?
    var voucherId: String?
    var isUsed: Bool?
    var createdAt: Date?

    /// Nested voucher details populated via Supabase join: .select("*, vouchers(*)")
    var vouchers: Voucher?

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case voucherId = "voucher_id"
        case isUsed    = "is_used"
        case createdAt = "created_at"
        case vouchers
    }
}

// MARK: - Custom Decoder for Voucher date formats

extension Voucher {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"
            dateOnly.locale = Locale(identifier: "en_US_POSIX")
            if let date = dateOnly.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }
}
