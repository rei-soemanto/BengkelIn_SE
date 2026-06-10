//
//  BengkelDTOs.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

struct BengkelUpdatePayload: Encodable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

struct BengkelServicesUpdatePayload: Encodable {
    let offered_services: [BengkelService]
}
