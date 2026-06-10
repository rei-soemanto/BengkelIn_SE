//
//  Bengkel.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import Foundation

struct Bengkel: Codable, Identifiable {
    var id: String?
    var providerUid: String
    var name: String
    var address: String
    
    var latitude: Double
    var longitude: Double
    
    var status: String
    
    var offeredServices: [BengkelService]
    
    var averageRating: Double
    var totalReviews: Int
    
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case providerUid = "provider_uid"
        case name
        case address
        case latitude
        case longitude
        case status
        case offeredServices = "offered_services"
        case averageRating = "average_rating"
        case totalReviews = "total_reviews"
        case createdAt = "created_at"
    }
}
