//
//  BidRepository.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 03/06/26.
//

import Foundation
import Supabase

// Direct CRUD on the `bids` table for the bidding subsystem. (The accept_bid RPC and
// the order-companion bid reads live in OrderRepository; this owns the bidding VMs'
// own bids-table access so the ViewModels never call `supabase` directly.)
class BidRepository {
    // Customer side: every offer for an order, cheapest first, with the bengkel joined.
    func fetchBids(serviceRequestId: String) async throws -> [Bid] {
        return try await supabase.from("bids")
            .select("*, bengkel:bengkels(*)")
            .eq("service_request_id", value: serviceRequestId)
            .order("price", ascending: true)
            .execute()
            .value
    }

    // Provider side: every bid this bengkel has placed.
    func fetchBidsForBengkel(bengkelId: String) async throws -> [Bid] {
        return try await supabase.from("bids")
            .select()
            .eq("bengkel_id", value: bengkelId)
            .execute()
            .value
    }

    func updateStatus(bidId: String, status: String) async throws {
        try await supabase.from("bids")
            .update(BidStatusUpdate(status: status))
            .eq("id", value: bidId)
            .execute()
    }
}
