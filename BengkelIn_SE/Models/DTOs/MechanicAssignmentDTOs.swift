//
//  MechanicAssignmentDTOs.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Foundation

// Param for the assign_mechanic RPC. p_mechanic_id == nil means "Self" (the provider
// works the job), which the SQL resolves to the caller's own uid.
struct AssignMechanicParams: Encodable {
    let p_request_id: String
    let p_mechanic_id: String?
}
