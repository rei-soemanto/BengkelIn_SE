//
//  Voucher.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//

import Foundation

// MARK: - Voucher Enums

enum DiscountType: String, Codable, CaseIterable {
    case percentage
    case fixed
}

enum VoucherScope: String, Codable, CaseIterable {
    case bengkelSpecific = "bengkel_specific"
    case platformWide = "platform_wide"
}

enum UserEligibility: String, Codable, CaseIterable {
    case allUsers = "all_users"
    case newUsersOnly = "new_users_only"
    case returningOnly = "returning_only"
}

// MARK: - Voucher Model

struct Voucher: Codable, Identifiable {
    let id: String
    let code: String

    // Discount Configuration
    let discountType: DiscountType
    let discountValue: Double
    let maximumDiscountAmount: Double?
    let minimumOrderValue: Double?

    // Scope & Targeting
    let scope: VoucherScope
    let issuedByBengkelId: String?
    let applicableServiceIds: [String]?

    // Usage Limits
    let globalUsageLimit: Int?
    let perUserUsageLimit: Int
    var currentUsageCount: Int

    // Time Window
    let startDate: Date
    let expiryDate: Date

    // Controls
    let isStackable: Bool
    var isActive: Bool
    let userEligibility: UserEligibility

    // Metadata
    let createdAt: Date
    let createdByUserId: String

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case discountType = "discount_type"
        case discountValue = "discount_value"
        case maximumDiscountAmount = "maximum_discount_amount"
        case minimumOrderValue = "minimum_order_value"
        case scope
        case issuedByBengkelId = "issued_by_bengkel_id"
        case applicableServiceIds = "applicable_service_ids"
        case globalUsageLimit = "global_usage_limit"
        case perUserUsageLimit = "per_user_usage_limit"
        case currentUsageCount = "current_usage_count"
        case startDate = "start_date"
        case expiryDate = "expiry_date"
        case isStackable = "is_stackable"
        case isActive = "is_active"
        case userEligibility = "user_eligibility"
        case createdAt = "created_at"
        case createdByUserId = "created_by_user_id"
    }
}
