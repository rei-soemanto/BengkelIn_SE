//
//  BiddingService.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 03/06/26.
//

import Foundation
import Supabase

// The `bidding` Supabase Edge Function. It isn't tied to a single table (it geo-filters
// open orders and places bids server-side), so it lives in a Service, not a Repository.
class BiddingService {
    func fetchOrdersForMechanic(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [NearbyOrder] {
        let body = OrdersRequest(
            action: "ordersForMechanic",
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
        let response: OrdersResponse = try await supabase.functions.invoke(
            "bidding",
            options: FunctionInvokeOptions(body: body)
        )
        return response.orders
    }

    @discardableResult
    func placeBid(serviceRequestId: String, bengkelId: String, price: Int, notes: String?) async throws -> Bid {
        let body = PlaceBidRequest(
            action: "placeBid",
            serviceRequestId: serviceRequestId,
            bengkelId: bengkelId,
            price: price,
            notes: notes
        )
        let response: PlaceBidResponse = try await supabase.functions.invoke(
            "bidding",
            options: FunctionInvokeOptions(body: body)
        )
        return response.bid
    }
}
