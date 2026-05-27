//
//  BengkelDTOs.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

// Used by BengkelRepository for name/address/coordinate updates
struct BengkelUpdatePayload: Encodable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

// Used by BengkelRepository to update the `mechanic_uids` array column
struct BengkelMechanicsUpdatePayload: Encodable {
    let mechanic_uids: [String]
}
