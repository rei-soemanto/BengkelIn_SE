//
//  MechanicInvitation.swift
//  BengkelIn_SE
//
//  Created for Mechanic Invitation feature on 07/05/26.
//

import Foundation

// MARK: - Invitation Status

enum InvitationStatus: String, Codable, CaseIterable {
    case pending  = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}

// MARK: - Mechanic Invitation Model

/// Maps directly to the `mechanic_invitations` table in Supabase.
struct MechanicInvitation: Codable, Identifiable {
    var id: String?
    var bengkelId: String
    var mechanicId: String
    var status: InvitationStatus
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case bengkelId   = "bengkel_id"
        case mechanicId  = "mechanic_id"
        case status
        case createdAt   = "created_at"
    }
}

// MARK: - Insert DTO (let DB handle id & created_at)

struct MechanicInvitationInsert: Encodable {
    let bengkelId: String
    let mechanicId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case bengkelId  = "bengkel_id"
        case mechanicId = "mechanic_id"
        case status
    }
}

// MARK: - Status Update DTO

struct MechanicInvitationStatusUpdate: Encodable {
    let status: String
}

// MARK: - Display Model (joined with bengkel name for the mechanic-side UI)

/// Used when fetching invitations with a joined bengkel name for display.
/// Query: `select("*, bengkels(name)")` → nested `bengkels` object.
struct MechanicInvitationDisplay: Codable, Identifiable {
    var id: String?
    var bengkelId: String
    var mechanicId: String
    var status: InvitationStatus
    var createdAt: Date?
    var bengkels: BengkelNameOnly?

    /// Helper to surface the bengkel name cleanly.
    var bengkelName: String {
        bengkels?.name ?? "Unknown Bengkel"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bengkelId   = "bengkel_id"
        case mechanicId  = "mechanic_id"
        case status
        case createdAt   = "created_at"
        case bengkels
    }
}

/// Lightweight struct to decode the nested `bengkels(name)` join.
struct BengkelNameOnly: Codable {
    let name: String
}
