//
//  BengkelBiddingViewModel.swift
//  BengkelIn_SE
//
//  Created for the bidding feature on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

/// Bengkel (provider) side of the bidding marketplace: a live feed of nearby open
/// requests, with the ability to place or revise a bid on each. Reacts in real time
/// to new requests and to the customer accepting/rejecting this bengkel's offers.
@MainActor
final class BengkelBiddingViewModel: ObservableObject {
    private let authService = AuthService()
    private let bengkelRepository = BengkelRepository()
    private let biddingService = BiddingService()
    private let bidRepository = BidRepository()

    @Published var nearbyOrders: [NearbyOrder] = []
    @Published var myBids: [Bid] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private(set) var myBengkel: Bengkel?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var hasStarted = false

    deinit {
        realtimeTask?.cancel()
        if let channel = realtimeChannel {
            Task { [channel] in await supabase.removeChannel(channel) }
        }
    }

    /// Resolve the caller's bengkel, load the feed once, then go live.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        isLoading = true
        errorMessage = nil
        do {
            let session = try await authService.getCurrentSession()
            let uid = session.user.id.uuidString.lowercased()
            self.myBengkel = try await bengkelRepository.fetchBengkel(providerUid: uid)
            await loadOrders()
            startRealtime(providerUid: uid)
        } catch {
            self.errorMessage = error.localizedDescription
            hasStarted = false
        }
        isLoading = false
    }

    /// Nearby open requests, minus any this bengkel has already lost (auto-rejected)
    /// or that timed out (expired). My current bids are kept for the "you bid X" state.
    func loadOrders() async {
        guard let bengkel = myBengkel,
              let bengkelId = bengkel.id,
              let lat = bengkel.latitude,
              let lon = bengkel.longitude else { return }
        do {
            async let ordersResult = biddingService.fetchNearbyOrders(latitude: lat, longitude: lon)
            async let myBidsResult = bidRepository.fetchBidsByBengkel(bengkelId: bengkelId)
            let orders = try await ordersResult
            let bids = try await myBidsResult

            self.myBids = bids
            let deadRequestIds = Set(
                bids.filter { $0.status == .autoRejected || $0.status == .expired }
                    .map { $0.serviceRequestId }
            )
            self.nearbyOrders = orders.filter { !deadRequestIds.contains($0.id) }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Place (or revise) a bid. The server re-checks open-state, bengkel ownership,
    /// and the customer's price floor; surfaced errors come straight through.
    @discardableResult
    func placeBid(order: NearbyOrder, price: Double, notes: String) async -> Bool {
        guard let bengkel = myBengkel, let bengkelId = bengkel.id else { return false }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            _ = try await biddingService.placeBid(
                serviceRequestId: order.id,
                bengkelId: bengkelId,
                price: price,
                notes: notes.isEmpty ? nil : notes
            )
            self.successMessage = "Tawaran terkirim."
            await loadOrders()
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// This bengkel's latest bid on a given order, if any.
    func myBid(for order: NearbyOrder) -> Bid? {
        myBids.first { $0.serviceRequestId == order.id }
    }

    // MARK: - Realtime (the one sanctioned direct-`supabase` use — see CLAUDE.md)

    private func startRealtime(providerUid: String) {
        stopRealtime()
        let channel = supabase.channel("mechanic_bids_\(providerUid)")
        self.realtimeChannel = channel
        // Our own bids changing (customer accepted/rejected) + the open-order feed shifting.
        let bidChanges = channel.postgresChange(
            AnyAction.self, schema: "public", table: "bids",
            filter: "provider_uid=eq.\(providerUid)"
        )
        let orderChanges = channel.postgresChange(
            AnyAction.self, schema: "public", table: "service_requests"
        )
        realtimeTask = Task { [weak self] in
            await channel.subscribe()
            await self?.loadOrders()           // cold-start reconcile after subscribe
            await withTaskGroup(of: Void.self) { group in
                group.addTask { for await _ in bidChanges { await self?.loadOrders() } }
                group.addTask { for await _ in orderChanges { await self?.loadOrders() } }
            }
        }
    }

    private func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel = realtimeChannel {
            Task { [channel] in await supabase.removeChannel(channel) }
            realtimeChannel = nil
        }
    }
}
