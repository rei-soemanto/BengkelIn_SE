//
//  BengkelRouteViewModel.swift
//  BengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import Foundation
import Combine
import CoreLocation
import Supabase

// Drives the route/work screen, role-aware so tracking matches who's handling the job:
//  • Dispatched mechanic  → publishes their live device GPS (they travel to the customer).
//  • Bengkel "Self"       → the handler is the SHOP, so we publish the bengkel's registered
//                           coordinates (a shop doesn't move; this avoids the phone's GPS —
//                           which in a simulator can sit on the customer — "teleporting" onto them).
//  • Provider monitoring  → doesn't publish; reads the assigned mechanic's order_locations so
//                           the provider can watch the mechanic + customer.
// The customer always reads order_locations to see whoever is assigned.
@MainActor
class BengkelRouteViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var order: NearbyOrder?
    @Published var bengkelCoordinate: CLLocationCoordinate2D?      // the viewer's own device GPS
    @Published var customerLiveCoordinate: CLLocationCoordinate2D?
    @Published var assigneeCoordinate: CLLocationCoordinate2D?     // location shown for the handler
    @Published var myUid: String?

    private let locationManager = CLLocationManager()
    private let orderRepository = OrderRepository()
    private let bengkelRepository = BengkelRepository()
    private let storageService = StorageService()
    private let locationRepository = OrderLocationRepository()
    private let authService = AuthService()
    private let notificationService = NotificationService()
    private var iInitiatedCancel = false

    private var serviceRequestId: String?
    private var customerCoordinate: CLLocationCoordinate2D?
    private var providerUid: String?
    private var shopCoordinate: CLLocationCoordinate2D?
    private var lastPublishedAt: Date?
    private var channel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    var status: String { order?.status ?? "pending" }

    // MARK: Role of the viewer relative to this order
    private var mechanicId: String? { order?.mechanicId }
    private var amProvider: Bool { myUid != nil && myUid == providerUid }
    var selfAssigned: Bool { mechanicId != nil && mechanicId == providerUid }   // bengkel handles it itself
    var amAssignee: Bool { mechanicId != nil && mechanicId == myUid }           // I'm the one handling it
    var viewerIsProvider: Bool { amProvider }                                   // I own this bengkel (can assign/reassign)
    private var monitoringMechanic: Bool { amProvider && mechanicId != nil && mechanicId != providerUid }
    // Label for the handler pin.
    var viewerIsAssignee: Bool { amAssignee }
    var handlerLabel: String {
        if amAssignee { return "Anda" }       // I'm doing the job (self-provider or mechanic)
        if monitoringMechanic { return "Mekanik" }  // provider watching the dispatched mechanic
        return "Bengkel"                       // unassigned provider previewing their shop
    }

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

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    func start(order: NearbyOrder) async {
        self.order = order
        self.serviceRequestId = order.id
        self.customerCoordinate = CLLocationCoordinate2D(latitude: order.latitude, longitude: order.longitude)
        self.myUid = try? await authService.currentUID()

        // Resolve the bengkel (provider uid + shop coordinates) so we can tell self-assignment
        // (shop is the handler) apart from a dispatched mechanic, and know if we're monitoring.
        if let bengkelId = order.bengkelId, let bengkel = try? await bengkelRepository.fetchById(id: bengkelId) {
            self.providerUid = bengkel.providerUid
            self.shopCoordinate = CLLocationCoordinate2D(latitude: bengkel.latitude, longitude: bengkel.longitude)
        }

        let auth = locationManager.authorizationStatus
        if auth == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.startUpdatingLocation()
        }

        if let loc = try? await locationRepository.fetchCustomerLocation(serviceRequestId: order.id) {
            self.customerLiveCoordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
        }

        await reconfigureForRole()

        stopChannel()
        let channel = supabase.channel("bengkel-route-\(order.id)")
        self.channel = channel
        let orderStream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "service_requests", filter: "id=eq.\(order.id)"
        )
        let customerLocationStream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "customer_locations", filter: "service_request_id=eq.\(order.id)"
        )
        let assigneeLocationStream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "order_locations", filter: "service_request_id=eq.\(order.id)"
        )
        realtimeReaderTasks.append(Task { [weak self] in
            guard let self else { return }
            await channel.subscribe()
            Task { [weak self] in
                for await _ in orderStream {
                    if let updated = try? await self?.orderRepository.fetchOrder(id: order.id) {
                        let previous = self?.order
                        self?.order = updated
                        self?.notifyOnCancellation(previous: previous, updated: updated)
                        await self?.reconfigureForRole()
                    }
                }
            }
            Task { [weak self] in
                for await _ in customerLocationStream {
                    if let loc = try? await self?.locationRepository.fetchCustomerLocation(serviceRequestId: order.id) {
                        self?.customerLiveCoordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
                    }
                }
            }
            Task { [weak self] in
                for await _ in assigneeLocationStream {
                    // Only the monitoring provider needs to mirror the published handler location.
                    await self?.refreshAssigneeFromOrderLocations()
                }
            }
        })
    }

    // Apply the display + publishing behavior for the current role/assignment.
    private func reconfigureForRole() async {
        if amAssignee {
            // I'm handling the job — mechanic OR bengkel "Self". Publish my live device GPS
            // so the customer (and a monitoring provider) sees me travel to them. Distinct
            // simulator locations (see scripts/sim-route.sh) keep me off the customer's spot.
            if let me = bengkelCoordinate { assigneeCoordinate = me }
            publishCurrentGPSIfPossible()
        } else if monitoringMechanic {
            // Provider watching a mechanic: mirror the mechanic's published location.
            await refreshAssigneeFromOrderLocations()
        } else if amProvider {
            // Unassigned provider at the gate: preview the bengkel at its shop so the map
            // always has a handler marker (don't leave it blank before assigning).
            if let shop = shopCoordinate { assigneeCoordinate = shop }
        }
    }

    private func refreshAssigneeFromOrderLocations() async {
        guard monitoringMechanic, let id = serviceRequestId else { return }
        if let loc = try? await locationRepository.fetchLocation(serviceRequestId: id) {
            self.assigneeCoordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        stopChannel()
    }

    func refreshOrder() async {
        guard let id = serviceRequestId else { return }
        if let updated = try? await orderRepository.fetchOrder(id: id) {
            self.order = updated
        }
    }

    // Called right after the provider assigns (Self or a mechanic) so the screen reflects the
    // new role immediately without waiting on realtime.
    func refreshAfterAssignment() async {
        await refreshOrder()
        await reconfigureForRole()
        let auth = locationManager.authorizationStatus
        if amAssignee, auth == .authorizedWhenInUse || auth == .authorizedAlways {
            locationManager.stopUpdatingLocation()
            locationManager.startUpdatingLocation()
        }
    }

    func reportIssue(reason: String, photoData: Data?) async -> Bool {
        guard let id = serviceRequestId else { return false }
        do {
            iInitiatedCancel = true
            var proofUrl: String? = nil
            if let photoData,
               let session = try? await authService.getCurrentSession() {
                let uid = session.user.id.uuidString.lowercased()
                proofUrl = try await storageService.uploadOrderPhoto(uid: uid, data: photoData)
            }
            _ = try await orderRepository.openDispute(requestId: id, reason: reason, proofUrl: proofUrl)
            return true
        } catch {
            iInitiatedCancel = false
            return false
        }
    }

    private func notifyOnCancellation(previous: NearbyOrder?, updated: NearbyOrder) {
        guard previous?.status != "cancelled", updated.status == "cancelled" else { return }
        if iInitiatedCancel { iInitiatedCancel = false; return }
        notificationService.notifyNewOrder(
            title: "Pesanan dibatalkan",
            body: "Pelanggan membatalkan pesanan ini."
        )
    }

    private func stopChannel() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            Task { await supabase.removeChannel(channel) }
            self.channel = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        if auth == .authorizedWhenInUse || auth == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.bengkelCoordinate = location.coordinate

        // The assignee (mechanic OR bengkel "Self") streams live GPS as the handler position.
        // A monitoring provider doesn't publish (it reads order_locations instead).
        guard amAssignee, status == "accepted", let requestId = serviceRequestId else { return }
        self.assigneeCoordinate = location.coordinate
        let distance = customerCoordinate.map {
            location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
        } ?? .greatestFiniteMagnitude
        let minInterval = interval(forDistance: distance)
        if let last = lastPublishedAt, Date().timeIntervalSince(last) < minInterval { return }
        lastPublishedAt = Date()
        Task { await publish(coordinate: location.coordinate, requestId: requestId) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func interval(forDistance meters: CLLocationDistance) -> TimeInterval {
        switch meters {
        case ..<1000: return 2
        case ..<3000: return 5
        default: return 10
        }
    }

    // Publish the latest known GPS immediately (e.g. right after assignment) so the handler's
    // marker appears without waiting for the next location update.
    private func publishCurrentGPSIfPossible() {
        guard amAssignee, status == "accepted", let requestId = serviceRequestId,
              let coord = bengkelCoordinate else { return }
        lastPublishedAt = Date()
        Task { await publish(coordinate: coord, requestId: requestId) }
    }

    private func publish(coordinate: CLLocationCoordinate2D, requestId: String) async {
        guard let session = try? await authService.getCurrentSession() else { return }
        let uid = session.user.id.uuidString.lowercased()
        try? await locationRepository.upsertLocation(OrderLocationPayload(
            service_request_id: requestId,
            provider_uid: uid,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
    }
}
