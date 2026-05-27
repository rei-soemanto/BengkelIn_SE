//
//  VehicleDTOs.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

// Used by VehicleRepository to update an existing vehicle record
struct VehicleUpdatePayload: Encodable {
    let manufacturer: String
    let model: String
    let year: Int
    let license_plate: String
    let color: String
}
