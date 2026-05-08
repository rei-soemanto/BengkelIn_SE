//
//  MechanicResignation.swift
//  BengkelIn
//

import Foundation

struct MechanicResignation: Codable, Identifiable {
    var id: String
    var bengkelId: String
    var mechanicId: String
    var status: String
    var createdAt: String?
    
    var users: ResigningUser?
    
    enum CodingKeys: String, CodingKey {
        case id
        case bengkelId = "bengkel_id"
        case mechanicId = "mechanic_id"
        case status
        case createdAt = "created_at"
        case users
    }
}

struct ResigningUser: Codable {
    var name: String
}

struct MechanicResignationInsert: Encodable {
    let bengkelId: String
    let mechanicId: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case bengkelId = "bengkel_id"
        case mechanicId = "mechanic_id"
        case status
    }
}
