//
//  MechanicResignationDTOs.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

// Used by MechanicResignationRepository when a mechanic requests to leave a bengkel
struct MechanicResignationInsert: Encodable {
    let bengkelId: String
    let mechanicId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case bengkelId  = "bengkel_id"
        case mechanicId = "mechanic_id"
        case status
    }
}
