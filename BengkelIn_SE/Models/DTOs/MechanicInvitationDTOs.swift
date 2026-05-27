//
//  MechanicInvitationDTOs.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

// Used by MechanicInvitationRepository to send a new invitation
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

// Used by MechanicInvitationRepository to update invitation status
struct MechanicInvitationStatusUpdate: Encodable {
    let status: String
}
