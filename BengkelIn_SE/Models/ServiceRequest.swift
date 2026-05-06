//
//  ServiceRequest.swift
//  BengkelIn_SE
//
//  Created for Phase 1 — Mechanic Backend Migration on 07/05/26.
//

import Foundation

// MARK: - Service Request Status

/// Represents the lifecycle of a service request.
/// Maps 1:1 to the `status` column (TEXT) in the `service_requests` table.
enum ServiceRequestStatus: String, Codable, CaseIterable {
    case pending     = "pending"
    case accepted    = "accepted"
    case inProgress  = "in_progress"
    case completed   = "completed"
    case cancelled   = "cancelled"
}

// MARK: - Service Request Model

/// Maps directly to the `service_requests` table in Supabase.
/// All CodingKeys match the snake_case column names.
struct ServiceRequest: Codable, Identifiable {
    var id: String?
    var customerId: String
    var vehicleId: String
    var bengkelId: String
    var serviceType: String
    var description: String?
    var status: ServiceRequestStatus
    var isEmergency: Bool
    var location: String?
    var latitude: Double?
    var longitude: Double?
    var estimatedPrice: Double?
    var mechanicNotes: String?
    var mechanicId: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
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
        case mechanicNotes  = "mechanic_notes"
        case mechanicId     = "mechanic_id"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }
}

// MARK: - Insert DTO (Only send writable columns — let DB handle id/timestamps)

/// A lean struct for creating new service requests.
/// Excludes `id`, `created_at`, `updated_at` which are database-managed.
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

// MARK: - Status Update DTO

/// Minimal struct for PATCH-updating a service request status.
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
