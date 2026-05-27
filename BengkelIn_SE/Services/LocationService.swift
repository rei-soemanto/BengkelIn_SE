//
//  LocationService.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//
//  Wraps the Photon OSM geocoder (photon.komoot.io).
//  Used by any LocationSearchable ViewModel for address autocomplete + reverse geocode.
//

import Foundation
import CoreLocation

enum LocationServiceError: LocalizedError {
    case invalidURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:   return "Invalid Photon URL."
        case .badResponse:  return "Bad response from Photon."
        }
    }
}

class LocationService {
    private let session: URLSession = .shared
    private let baseHost = "photon.komoot.io"

    /// Forward search — returns ranked matches for a query, optionally biased to a coordinate.
    func searchOSM(query: String, coordinate: CLLocationCoordinate2D? = nil) async throws -> [PhotonSearchFeature] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents()
        components.scheme = "https"
        components.host = baseHost
        components.path = "/api/"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: "8")
        ]
        if let coord = coordinate {
            items.append(URLQueryItem(name: "lat", value: String(coord.latitude)))
            items.append(URLQueryItem(name: "lon", value: String(coord.longitude)))
        }
        components.queryItems = items

        guard let url = components.url else { throw LocationServiceError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LocationServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(PhotonSearchResponse.self, from: data)
        return decoded.features
    }

    /// Reverse geocode — returns a human-readable address for a coordinate.
    /// Returns `nil` if no result is found.
    func fetchAddress(from coordinate: CLLocationCoordinate2D) async throws -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = baseHost
        components.path = "/reverse"
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude))
        ]

        guard let url = components.url else { throw LocationServiceError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LocationServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(PhotonSearchResponse.self, from: data)
        return decoded.features.first?.displayName
    }
}
