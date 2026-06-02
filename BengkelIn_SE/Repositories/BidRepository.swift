//
//  BidRepository.swift
//  BengkelIn_SE
//
//  Created for the bidding feature on 02/06/26.
//

import Foundation
import Supabase

/// CRUD on the `bids` table plus the `accept_bid` RPC. Bid placement and the
/// nearby-order feed go through `BiddingService` (the `bidding` edge function);
/// this repository covers the reads and the direct status writes.
class BidRepository {
    /// All bids on a request, cheapest first, each with its bengkel joined in.
    func fetchBids(serviceRequestId: String) async throws -> [Bid] {
        return try await supabase.from("bids")
            .select("*, bengkel:bengkels(*)")
            .eq("service_request_id", value: serviceRequestId)
            .order("price", ascending: true)
            .execute()
            .value
    }

    /// Every bid a bengkel has placed — used to drive the bengkel's bid history
    /// and to detect accepted/rejected/expired transitions.
    func fetchBidsByBengkel(bengkelId: String) async throws -> [Bid] {
        return try await supabase.from("bids")
            .select()
            .eq("bengkel_id", value: bengkelId)
            .execute()
            .value
    }

    /// Atomically accept a bid (server-authoritative `accept_bid`): balance-gated,
    /// auto-rejects sibling bids, assigns the winning bengkel + price to the order.
    func acceptBid(bidId: String) async throws {
        try await supabase.rpc("accept_bid", params: ["p_bid_id": bidId]).execute()
    }

    /// Customer reject ("rejected") or timeout ("expired") of a single offer.
    func updateBidStatus(bidId: String, status: BidStatus) async throws {
        try await supabase.from("bids")
            .update(BidStatusUpdate(status: status.rawValue))
            .eq("id", value: bidId)
            .execute()
    }
}
