//
//  MechanicAssignmentDTOs.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Foundation

struct AssignMechanicParams: Encodable {
    let p_request_id: String
    let p_mechanic_id: String
}

struct AvailableMechanicsParams: Encodable {
    let p_request_id: String
}
