//
//  Bid.swift
//  BengkelIn_SE
//
//  Created for the bidding feature on 02/06/26.
//

import Foundation

// MARK: - Bid Status

/// Negotiation state of an offer. Maps 1:1 to the `status` column of `bids`.
enum BidStatus: String, Codable, CaseIterable {
    case pending      = "pending"
    case accepted     = "accepted"
    case rejected     = "rejected"      // customer declined this bengkel's price (can re-bid)
    case autoRejected = "autorejected"  // customer accepted a different bengkel
    case expired      = "expired"       // the decision window elapsed
}

// MARK: - Bid Model

/// A pricing proposal from a bengkel on a customer's broadcast `ServiceRequest`.
/// Maps to the `bids` table. The optional `bengkel` is populated when fetched with
/// `.select("*, bengkel:bengkels(*)")`.
struct Bid: Codable, Identifiable {
    var id: String?
    var serviceRequestId: String
    var providerUid: String
    var bengkelId: String
    var price: Double
    var notes: String?
    var status: BidStatus
    var createdAt: Date?
    var bengkel: Bengkel?

    enum CodingKeys: String, CodingKey {
        case id
        case serviceRequestId = "service_request_id"
        case providerUid      = "provider_uid"
        case bengkelId         = "bengkel_id"
        case price
        case notes
        case status
        case createdAt         = "created_at"
        case bengkel
    }
}
