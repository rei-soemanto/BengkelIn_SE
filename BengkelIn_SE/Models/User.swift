//
//  User.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

struct User: Codable, Identifiable {
    var id: String
    var name: String
    var profileImageUrl: String?
    var balance: Double?
    var email: String?
    var phoneNumber: String?
    var role: String?
    
    // Multi-role flags (mock-only for now, backend TBD)
    var isMechanic: Bool?
    var isProvider: Bool?

    // Wallet / payout (Phase 0: escrow balance + Midtrans top-up + withdrawals)
    var heldBalance: Double?
    var pendingBalance: Double?
    var bankName: String?
    var bankAccountNumber: String?
    var bankAccountName: String?

    /// Funds free to withdraw (balance minus escrow held for active orders).
    var availableBalance: Double { max(0, (balance ?? 0) - (heldBalance ?? 0)) }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case profileImageUrl = "profile_image_url"
        case balance
        case role
        case isMechanic = "is_mechanic"
        case isProvider = "is_provider"
        case heldBalance = "held_balance"
        case pendingBalance = "pending_balance"
        case bankName = "bank_name"
        case bankAccountNumber = "bank_account_number"
        case bankAccountName = "bank_account_name"
    }
}
