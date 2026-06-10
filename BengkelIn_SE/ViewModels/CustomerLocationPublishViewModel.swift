//
//  CustomerLocationPublishViewModel.swift
//  BengkelIn
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Foundation
import Combine
import CoreLocation
import Supabase

// Customer-side: publishes the customer's live GPS for an in-progress order so
// the assigned bengkel sees them move in realtime (customer_locations table).
@MainActor
class CustomerLocationPublishViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isPublishing = false
    @Published var errorMessage: String?
    // The customer's latest device fix, exposed so the tracking view can judge
    // real proximity to the bengkel (the order's static location is not the
    // customer's current position once they move).
    @Published var currentCoordinate: CLLocationCoordinate2D?

    private let locationManager = CLLocationManager()
    private let repository = OrderLocationRepository()
    private let authService = AuthService()

    private var serviceRequestId: String?
    private var lastPublishedAt: Date?
    private let minInterval: TimeInterval = 3

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.pausesLocationUpdatesAutomatically = false
        // Background location updates require the `location` UIBackgroundMode in
        // the bundle's Info.plist; enabling them without it throws at runtime.
        if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
           backgroundModes.contains("location") {
            locationManager.allowsBackgroundLocationUpdates = true
        }
    }

    func start(serviceRequestId: String) {
        self.serviceRequestId = serviceRequestId
        self.lastPublishedAt = nil
        isPublishing = true
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        isPublishing = false
        serviceRequestId = nil
        lastPublishedAt = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if isPublishing, status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isPublishing, let location = locations.last, let requestId = serviceRequestId else { return }
        // Update the exposed coordinate on every fix (the DB publish below is
        // throttled, but proximity should react to the freshest position).
        self.currentCoordinate = location.coordinate
        if let last = lastPublishedAt, Date().timeIntervalSince(last) < minInterval { return }
        lastPublishedAt = Date()
        Task { await publish(coordinate: location.coordinate, requestId: requestId) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func publish(coordinate: CLLocationCoordinate2D, requestId: String) async {
        guard let session = try? await authService.getCurrentSession() else { return }
        let uid = session.user.id.uuidString.lowercased()
        do {
            try await repository.upsertCustomerLocation(CustomerLocationPayload(
                service_request_id: requestId,
                customer_id: uid,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ))
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
