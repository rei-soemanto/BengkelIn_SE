//
//  ServiceRequest.swift
//  BengkelIn_SE
//
//  Created for Phase 1 — Mechanic Backend Migration on 07/05/26.
//

import Foundation

// MARK: - Service Request Status

/// Lifecycle of a service request. Maps 1:1 to the `status` column of `service_requests`.
enum ServiceRequestStatus: String, Codable, CaseIterable {
    case pending     = "pending"
    case accepted    = "accepted"
    case inProgress  = "in_progress"
    case completed   = "completed"
    case cancelled   = "cancelled"
}

// MARK: - Service Request Model

/// Maps directly to the `service_requests` table in Supabase.
struct ServiceRequest: Codable, Identifiable {
    var id: String?
    var customerId: String
    var vehicleId: String?   // optional: bidding broadcasts may omit a vehicle
    var bengkelId: String?   // nil until a bid is accepted (bidding) or set directly
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

    // Completion + rating (Phase 0 combine)
    var completedAt: Date?
    var customerCompleted: Bool?
    var providerCompleted: Bool?
    var completionPhotoUrl: String?
    var rating: Int?
    var review: String?

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
        case completedAt          = "completed_at"
        case customerCompleted    = "customer_completed"
        case providerCompleted    = "provider_completed"
        case completionPhotoUrl   = "completion_photo_url"
        case rating
        case review
    }
}
