//
//  OrderTrackingViewModel.swift
//  BengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import Foundation
import Combine
import CoreLocation
import Supabase

// Customer-side: for an in-progress order, subscribes via Supabase Realtime to
//  1) the assigned bengkel's live location (order_locations), and
//  2) the order row itself (service_requests) — so the moment it settles to
//     "completed" we can prompt the customer for a review.
@MainActor
class OrderTrackingViewModel: ObservableObject, Sendable {
    @Published var providerCoordinate: CLLocationCoordinate2D?
    @Published var lastUpdated: String?
    @Published var order: NearbyOrder?
    @Published var isLive = false
    @Published var errorMessage: String?

    private let locationRepository = OrderLocationRepository()
    private let orderRepository = OrderRepository()
    private let notificationService = NotificationService()
    private var iInitiatedCancel = false
    private var channel: RealtimeChannelV2?
    private var serviceRequestId: String?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    var status: String { order?.status ?? "accepted" }
    var alreadyRated: Bool { (order?.rating ?? 0) > 0 }

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    func start(serviceRequestId: String) async {
        self.serviceRequestId = serviceRequestId
        // Notification authorization is requested when tracking begins.

        // Seed with whatever is already known.
        if let location = try? await locationRepository.fetchLocation(serviceRequestId: serviceRequestId) {
            apply(location)
        }
        self.order = try? await orderRepository.fetchOrder(id: serviceRequestId)

        stop()
        let channel = supabase.channel("order-tracking-\(serviceRequestId)")
        self.channel = channel

        let locationStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "order_locations",
            filter: "service_request_id=eq.\(serviceRequestId)"
        )
        let orderStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: "id=eq.\(serviceRequestId)"
        )

        realtimeReaderTasks.append(Task { [weak self] in
            guard let self else { return }
            await channel.subscribe()

            Task { [weak self] in
                guard let self else { return }
                for await status in channel.statusChange {
                    if status != .subscribed { self.isLive = false }
                }
            }
            Task { [weak self] in
                for await _ in locationStream {
                    guard let self else { return }
                    if let location = try? await self.locationRepository.fetchLocation(serviceRequestId: serviceRequestId) {
                        self.apply(location)
                        self.isLive = true
                    }
                }
            }
            Task { [weak self] in
                for await _ in orderStream {
                    guard let self else { return }
                    if let updated = try? await self.orderRepository.fetchOrder(id: serviceRequestId) {
                        let previous = self.order
                        self.order = updated
                        self.notifyOnCancellation(previous: previous, updated: updated)
                        self.notifyOnAssignment(previous: previous, updated: updated)
                    }
                }
            }
        })
    }

    func stop() {
        isLive = false
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            Task { await supabase.removeChannel(channel) }
            self.channel = nil
        }
    }

    func openDispute(reason: String) async -> Bool {
        guard let id = serviceRequestId else { return false }
        errorMessage = nil
        do {
            iInitiatedCancel = true
            _ = try await orderRepository.openDispute(requestId: id, reason: reason)
            return true
        } catch {
            iInitiatedCancel = false
            // Was returned silently before — the cancel sheet just sat there doing nothing.
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func notifyOnCancellation(previous: NearbyOrder?, updated: NearbyOrder) {
        guard previous?.status != "cancelled", updated.status == "cancelled" else { return }
        if iInitiatedCancel { iInitiatedCancel = false; return }
        notificationService.notifyNewOrder(
            title: "Pesanan dibatalkan",
            body: "Bengkel membatalkan pesanan ini."
        )
    }

    // Fires once when the bengkel assigns a handler (itself or a mechanic), i.e.
    // mechanic_id goes from unset to set — the customer learns help is en route.
    private func notifyOnAssignment(previous: NearbyOrder?, updated: NearbyOrder) {
        guard previous?.mechanicId == nil, updated.mechanicId != nil else { return }
        notificationService.notifyNewOrder(
            title: "Bengkel menuju lokasimu",
            body: "Bengkel sudah menugaskan dan sedang dalam perjalanan ke lokasimu."
        )
    }

    func notifyBengkelNear() {
        notificationService.notifyNewOrder(
            title: "Bengkel sudah dekat",
            body: "Bengkel berada di sekitar lokasimu. Kamu bisa menyelesaikan pesanan."
        )
    }

    private func apply(_ location: OrderLocation) {
        self.providerCoordinate = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        self.lastUpdated = location.updatedAt
    }
}
