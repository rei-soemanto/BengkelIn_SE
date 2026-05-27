//
//  PhotonSearchResponse.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//
//  Decodes responses from the Photon OSM geocoder (photon.komoot.io).
//

import Foundation

// MARK: - Top-level response

struct PhotonSearchResponse: Decodable {
    let features: [PhotonSearchFeature]
}

// MARK: - Feature (one search result)

struct PhotonSearchFeature: Decodable, Identifiable {
    /// Stable identifier built from OSM type + id so SwiftUI ForEach can diff results.
    var id: String { "\(properties.osmType ?? "?")-\(properties.osmId ?? 0)" }
    let geometry: PhotonGeometry
    let properties: PhotonProperties

    /// Convenience: GeoJSON coordinates are [lon, lat].
    var latitude: Double { geometry.coordinates.count > 1 ? geometry.coordinates[1] : 0 }
    var longitude: Double { geometry.coordinates.count > 0 ? geometry.coordinates[0] : 0 }

    /// Human-friendly single-line display name composed from available property fields.
    var displayName: String {
        let parts: [String?] = [
            properties.name,
            [properties.housenumber, properties.street].compactMap { $0 }.joined(separator: " ").nilIfEmpty,
            properties.district,
            properties.city,
            properties.state,
            properties.country
        ]
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct PhotonGeometry: Decodable {
    let coordinates: [Double] // [lon, lat]
}

struct PhotonProperties: Decodable {
    let name: String?
    let street: String?
    let housenumber: String?
    let district: String?
    let city: String?
    let state: String?
    let country: String?
    let osmId: Int?
    let osmType: String?

    enum CodingKeys: String, CodingKey {
        case name, street, housenumber, district, city, state, country
        case osmId   = "osm_id"
        case osmType = "osm_type"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
