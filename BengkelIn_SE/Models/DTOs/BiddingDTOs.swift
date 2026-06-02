//
//  BiddingDTOs.swift
//  BengkelIn_SE
//
//  Created for the bidding feature on 02/06/26.
//

import Foundation

// MARK: - Broadcast request insert (customer side)

/// Insert payload for a bidding broadcast — a `service_requests` row with NO
/// bengkel yet (the direct-request flow uses `ServiceRequestInsert` instead).
/// DB manages id, created_at, updated_at, bengkel_id (null until a bid is accepted).
struct BiddingRequestInsert: Encodable {
    let customerId: String
    let vehicleId: String?
    let serviceType: String
    let description: String?
    let status: String          // "pending"
    let isEmergency: Bool
    let location: String?
    let latitude: Double?
    let longitude: Double?
    let estimatedPrice: Double?

    enum CodingKeys: String, CodingKey {
        case customerId     = "customer_id"
        case vehicleId      = "vehicle_id"
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

// MARK: - `bidding` edge function bodies (camelCase — read directly by the function)

/// Body for the `ordersForMechanic` / `mechanicsForCustomer` actions.
struct OrdersRequest: Encodable {
    let action: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Int
}

/// `{ "orders": [...] }` from the `ordersForMechanic` action.
struct OrdersResponse: Decodable {
    let orders: [NearbyOrder]
}

/// Body for the `placeBid` action.
struct PlaceBidRequest: Encodable {
    let action: String
    let serviceRequestId: String
    let bengkelId: String
    let price: Double
    let notes: String?
}

/// `{ "bid": {...} }` from the `placeBid` action.
struct PlaceBidResponse: Decodable {
    let bid: Bid
}

// MARK: - Direct table writes

/// Updates a bid's status (customer reject / timeout-expire).
struct BidStatusUpdate: Encodable {
    let status: String
}
