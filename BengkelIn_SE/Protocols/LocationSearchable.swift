//
//  LocationSearchable.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//
//  Shared contract for any ViewModel that drives the map + search address picker.
//

import Foundation
import MapKit

@MainActor
protocol LocationSearchable: ObservableObject {
    var locationAddress: String { get set }
    var isEditingLocation: Bool { get set }
    var isFetchingLocation: Bool { get }
    var searchResults: [PhotonSearchFeature] { get set }
    var region: MKCoordinateRegion { get set }

    func useCurrentLocation()
    func selectSearchResult(_ result: PhotonSearchFeature)
    func updateLocationFromMap(coordinate: CLLocationCoordinate2D)
}
