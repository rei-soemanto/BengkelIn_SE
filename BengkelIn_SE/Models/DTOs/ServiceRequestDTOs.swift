//
//  ServiceRequestDTOs.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

// Insert payload — DB manages id, created_at, updated_at
struct ServiceRequestInsert: Encodable {
    let customerId: String
    let vehicleId: String
    let bengkelId: String
    let serviceType: String
    let description: String?
    let status: String
    let isEmergency: Bool
    let location: String?
    let latitude: Double?
    let longitude: Double?
    let estimatedPrice: Double?

    enum CodingKeys: String, CodingKey {
        case customerId     = "customer_id"
        case vehicleId      = "vehicle_id"
        case bengkelId      = "bengkel_id"
        case serviceType    = "service_type"
        case description
        case status
        case isEmergency    = "is_emergency"
        case location
        case latitude
        case longitude
        case estimatedPrice = "estimated_price"
    }
}

// Status update payload — used for all status transitions and optional mechanic assignment
struct ServiceRequestStatusUpdate: Encodable {
    let status: String
    let mechanicNotes: String?
    var mechanicId: String? = nil
    let updatedAt: String // ISO 8601 string for the `updated_at` column

    enum CodingKeys: String, CodingKey {
        case status
        case mechanicNotes = "mechanic_notes"
        case mechanicId    = "mechanic_id"
        case updatedAt     = "updated_at"
    }
}
