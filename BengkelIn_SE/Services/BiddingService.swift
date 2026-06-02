//
//  BiddingService.swift
//  BengkelIn_SE
//
//  Created for the bidding feature on 02/06/26.
//

import Foundation
import Supabase

/// Wraps the `bidding` edge function (geospatial order feed + bid placement).
/// Lives in Services (not a Repository) because it invokes an edge function
/// rather than doing direct table CRUD.
class BiddingService {
    /// Open broadcast orders near a bengkel, nearest first (`ordersForMechanic`).
    func fetchNearbyOrders(latitude: Double, longitude: Double, radiusMeters: Int = 5000) async throws -> [NearbyOrder] {
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

    /// Place (or revise) a bid on a broadcast order. Server enforces open-state,
    /// bengkel ownership, and the customer's price floor.
    @discardableResult
    func placeBid(serviceRequestId: String, bengkelId: String, price: Double, notes: String?) async throws -> Bid {
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
