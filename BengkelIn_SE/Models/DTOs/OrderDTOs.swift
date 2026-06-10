//
//  OrderDTOs.swift
//  BengkelIn
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import Foundation

struct ServiceRequestPayload: Encodable {
    let customer_id: String
    let service_type: ServiceType
    let description: String
    let latitude: Double
    let longitude: Double
    let price: Int
    let is_emergency: Bool
    let status: String
    let tire_count: Int
    let photo_urls: [String]?
    let vehicle_id: String?
    let vehicle_info: String?
    let use_points: Bool
}

struct CreatedServiceRequest: Decodable {
    let id: String
}

struct OpenDisputeParams: Encodable {
    let p_request_id: String
    let p_reason: String
    let p_proof_url: String?
}

struct TodaysEarningRow: Decodable {
    let price: Int?
}

struct BidStatusUpdate: Encodable {
    let status: String
}

struct AcceptBidParams: Encodable {
    let p_bid_id: String
}

struct CancelOrderParams: Encodable {
    let p_request_id: String
}

struct StartSearchPayload: Encodable {
    let price: Int
}

struct RateOrderParams: Encodable {
    let p_request_id: String
    let p_rating: Int
}

struct OrdersRequest: Encodable {
    let action: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
}

struct OrdersResponse: Decodable {
    let orders: [NearbyOrder]
}

struct PlaceBidRequest: Encodable {
    let action: String
    let serviceRequestId: String
    let bengkelId: String
    let price: Int
    let notes: String?
}

struct PlaceBidResponse: Decodable {
    let bid: Bid
}

struct OrderLocationPayload: Encodable {
    let service_request_id: String
    let provider_uid: String
    let latitude: Double
    let longitude: Double
}

struct CustomerLocationPayload: Encodable {
    let service_request_id: String
    let customer_id: String
    let latitude: Double
    let longitude: Double
}

struct BehaviorReportPayload: Encodable {
    let service_request_id: String
    let reporter_id: String
    let reason: String
}

struct ReportedRequestRow: Decodable {
    let service_request_id: String
}
