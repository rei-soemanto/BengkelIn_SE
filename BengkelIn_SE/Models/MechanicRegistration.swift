//
//  MechanicRegistration.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import Foundation

struct RosterMember: Codable, Identifiable {
    var registrationId: String
    var mechanicId: String
    var mechanicName: String
    var mechanicEmail: String?
    var status: String
    var createdAt: String?

    var id: String { registrationId }
    var isPending: Bool { status == "Pending" }
    var isAccepted: Bool { status == "Accepted" }

    enum CodingKeys: String, CodingKey {
        case registrationId = "registration_id"
        case mechanicId = "mechanic_id"
        case mechanicName = "mechanic_name"
        case mechanicEmail = "mechanic_email"
        case status
        case createdAt = "created_at"
    }
}

struct MechanicInvite: Codable, Identifiable {
    var registrationId: String
    var bengkelId: String
    var bengkelName: String
    var status: String
    var createdAt: String?

    var id: String { registrationId }
    var isPending: Bool { status == "Pending" }

    enum CodingKeys: String, CodingKey {
        case registrationId = "registration_id"
        case bengkelId = "bengkel_id"
        case bengkelName = "bengkel_name"
        case status
        case createdAt = "created_at"
    }
}

struct AvailableMechanic: Codable, Identifiable {
    var mechanicId: String
    var mechanicName: String
    var busy: Bool
    var isCurrent: Bool

    var id: String { mechanicId }

    enum CodingKeys: String, CodingKey {
        case mechanicId = "mechanic_id"
        case mechanicName = "mechanic_name"
        case busy
        case isCurrent = "is_current"
    }
}
