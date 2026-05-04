//
//  Mechanic.swift
//  BengkelIn_SE
//
//  Created for Mechanic feature on 05/05/26.
//

import Foundation

enum MechanicStatus: String, Codable, CaseIterable {
    case available = "Available"
    case busy = "Busy"
}

struct Mechanic: Codable, Identifiable {
    var id: String
    var name: String
    var status: MechanicStatus
    var linkedBengkelId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case linkedBengkelId = "linked_bengkel_id"
    }
}
