//
//  MechanicAssignmentDTOs.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Foundation

// Param for the assign_mechanic RPC. A mechanic is required — bengkel "Self" assignment
// was removed, so the RPC rejects a null mechanic.
struct AssignMechanicParams: Encodable {
    let p_request_id: String
    let p_mechanic_id: String
}

// Param for the available_mechanics RPC — the order being assigned, so the picker can flag
// busy mechanics and the one currently assigned.
struct AvailableMechanicsParams: Encodable {
    let p_request_id: String
}
