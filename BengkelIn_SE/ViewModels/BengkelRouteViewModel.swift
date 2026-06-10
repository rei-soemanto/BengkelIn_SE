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

@MainActor
final class RouteLocationStore: ObservableObject {
    @Published var me: CLLocationCoordinate2D?
    @Published var customer: CLLocationCoordinate2D?
    @Published var handler: CLLocationCoordinate2D?
}

@MainActor
class BengkelRouteViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var order: NearbyOrder?
    @Published var myUid: String?
    @Published var reassignedAway = false
    private var wasAssignee = false

    let locationStore = RouteLocationStore()
    var isPaused = false
    var bengkelCoordinate: CLLocationCoordinate2D? {
        get { locationStore.me } set { guard !isPaused else { return }; locationStore.me = newValue }
    }
    var customerLiveCoordinate: CLLocationCoordinate2D? {
        get { locationStore.customer } set { guard !isPaused else { return }; locationStore.customer = newValue }
    }
    var assigneeCoordinate: CLLocationCoordinate2D? {
        get { locationStore.handler } set { guard !isPaused else { return }; locationStore.handler = newValue }
    }

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
    private var reassignObserver: NSObjectProtocol?

    var status: String { order?.status ?? "pending" }

    private var mechanicId: String? { order?.mechanicId }
    private var amProvider: Bool { myUid != nil && myUid == providerUid }
    var selfAssigned: Bool { mechanicId != nil && mechanicId == providerUid }
    var amAssignee: Bool { mechanicId != nil && mechanicId == myUid }
    var viewerIsProvider: Bool { amProvider }
    private var monitoringMechanic: Bool { amProvider && mechanicId != nil && mechanicId != providerUid }
    var viewerIsAssignee: Bool { amAssignee }
    var handlerLabel: String {
        if amAssignee { return "Anda" }
        if monitoringMechanic { return "Mekanik" }
        return "Bengkel"
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
        reassignObserver = NotificationCenter.default.addObserver(
            forName: .mechanicReassignedAway, object: nil, queue: .main
        ) { [weak self] note in
            guard let id = note.object as? String else { return }
            Task { @MainActor in
                guard let self else { return }
                if id == self.serviceRequestId, self.wasAssignee { self.reassignedAway = true }
            }
        }
    }

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let reassignObserver { NotificationCenter.default.removeObserver(reassignObserver) }
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

        await resolveBengkelIfNeeded()

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
                        await self?.resolveBengkelIfNeeded()
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
                    await self?.refreshAssigneeFromOrderLocations()
                }
            }
        })

        realtimeReaderTasks.append(Task { [weak self] in
            var misses = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard let self else { return }
                guard self.wasAssignee, !self.reassignedAway, let id = self.serviceRequestId else { misses = 0; continue }
                if let fresh = try? await self.orderRepository.fetchOrder(id: id) {
                    if fresh.mechanicId != self.myUid { self.reassignedAway = true } else { misses = 0 }
                } else {
                    misses += 1
                    if misses >= 2 { self.reassignedAway = true }
                }
            }
        })
    }

    private func resolveBengkelIfNeeded() async {
        guard providerUid == nil,
              let bengkelId = order?.bengkelId,
              let bengkel = try? await bengkelRepository.fetchById(id: bengkelId) else { return }
        self.providerUid = bengkel.providerUid
        self.shopCoordinate = CLLocationCoordinate2D(latitude: bengkel.latitude, longitude: bengkel.longitude)
    }

    private func reconfigureForRole() async {
        if amAssignee {
            wasAssignee = true
        } else if wasAssignee, mechanicId != nil {
            reassignedAway = true
        }

        if amAssignee {
            if let me = bengkelCoordinate { assigneeCoordinate = me }
            publishCurrentGPSIfPossible()
        } else if monitoringMechanic {
            await refreshAssigneeFromOrderLocations()
        } else if amProvider {
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

    func refreshAfterAssignment() async {
        await refreshOrder()
        await resolveBengkelIfNeeded()
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
