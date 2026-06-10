//
//  BidRepository.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 03/06/26.
//

import Foundation
import Supabase

class BidRepository {
    func fetchAcceptedBid(serviceRequestId: String) async throws -> Bid? {
        let bids: [Bid] = try await supabase.from("bids")
            .select("*, bengkel:bengkels(*)")
            .eq("service_request_id", value: serviceRequestId)
            .eq("status", value: "Accepted")
            .limit(1)
            .execute()
            .value
        return bids.first
    }

    func fetchBids(serviceRequestId: String) async throws -> [Bid] {
        return try await supabase.from("bids")
            .select("*, bengkel:bengkels(*)")
            .eq("service_request_id", value: serviceRequestId)
            .order("price", ascending: true)
            .execute()
            .value
    }

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
