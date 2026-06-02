//
//  NearbyOrder.swift
//  BengkelIn_SE
//
//  Created for the bidding feature on 02/06/26.
//

import Foundation

/// A broadcast service request with its distance from a bengkel, as returned by
/// the `nearby_service_requests` RPC (via the `bidding` edge function). This is a
/// denormalized read model — distinct from `ServiceRequest` — so the bengkel's
/// order feed never has to decode the full request row.
struct NearbyOrder: Codable, Identifiable {
    var id: String
    var customerId: String
    var customerName: String?
    var serviceType: String?
    var description: String?
    var isEmergency: Bool?
    var latitude: Double
    var longitude: Double
    var estimatedPrice: Double?
    var status: String?
    var createdAt: Date?
    var distanceM: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case customerId     = "customer_id"
        case customerName   = "customer_name"
        case serviceType    = "service_type"
        case description
        case isEmergency    = "is_emergency"
        case latitude
        case longitude
        case estimatedPrice = "estimated_price"
        case status
        case createdAt      = "created_at"
        case distanceM      = "distance_m"
    }
}
