//
//  MechanicDTOs.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import Foundation

// Params for the mechanic-roster RPCs (UC8). snake_case to match the SQL arg names.

struct InviteMechanicParams: Encodable {
    let p_email: String
}

struct RespondInviteParams: Encodable {
    let p_registration_id: String
    let p_accept: Bool
}

struct RemoveMechanicParams: Encodable {
    let p_registration_id: String
}
