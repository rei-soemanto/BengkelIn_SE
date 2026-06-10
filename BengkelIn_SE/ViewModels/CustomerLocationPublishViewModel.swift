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

@MainActor
class CustomerLocationPublishViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isPublishing = false
    @Published var errorMessage: String?
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
            if !(error is CancellationError) {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
