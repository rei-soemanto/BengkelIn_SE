//
//  CustomerBiddingViewModel.swift
//  BengkelIn_SE
//
//  Created for the bidding feature on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

/// Customer side of the bidding marketplace: broadcast a request (no bengkel),
/// watch incoming bids live, and accept or reject them. Drives the search/offer UI.
@MainActor
final class CustomerBiddingViewModel: ObservableObject {
    private let authService = AuthService()
    private let bidRepository = BidRepository()
    private let serviceRequestRepository = ServiceRequestRepository()

    // Request inputs, fixed for the session (set from the create-order screen).
    let serviceType: String
    let latitude: Double
    let longitude: Double
    let location: String?
    let vehicleId: String?
    @Published var bidPrice: Double

    // Session state.
    @Published var serviceRequestId: String?
    @Published var bids: [Bid] = []
    @Published var acceptedBid: Bid?
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchSecondsRemaining = 0
    @Published var showRetryPrompt = false
    @Published var shouldDismiss = false

    private let searchTimeoutSeconds = 120
    private var countdownTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    init(serviceType: String, latitude: Double, longitude: Double,
         location: String?, vehicleId: String?, bidPrice: Double) {
        self.serviceType = serviceType
        self.latitude = latitude
        self.longitude = longitude
        self.location = location
        self.vehicleId = vehicleId
        self.bidPrice = bidPrice
    }

    deinit {
        countdownTask?.cancel()
        realtimeTask?.cancel()
        if let channel = realtimeChannel {
            Task { [channel] in await supabase.removeChannel(channel) }
        }
    }

    // MARK: - Broadcast lifecycle

    /// Creates the broadcast request (status "pending", no bengkel) and starts
    /// listening for bids. Returns false if the request could not be created.
    @discardableResult
    func startSearch() async -> Bool {
        guard serviceRequestId == nil else { return true }
        guard bidPrice > 0 else {
            errorMessage = "Masukkan harga tawaran yang valid."
            return false
        }
        isLoading = true
        errorMessage = nil
        do {
            let session = try await authService.getCurrentSession()
            let uid = session.user.id.uuidString.lowercased()
            let payload = BiddingRequestInsert(
                customerId: uid,
                vehicleId: vehicleId,
                serviceType: serviceType,
                description: nil,
                status: ServiceRequestStatus.pending.rawValue,
                isEmergency: false,
                location: location,
                latitude: latitude,
                longitude: longitude,
                estimatedPrice: bidPrice
            )
            let created = try await serviceRequestRepository.insertBroadcast(payload)
            self.serviceRequestId = created.id
            self.isSearching = true
            startRealtime()
            await loadBids()
            startCountdown()
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// Refreshes the offer list; promotes an accepted bid and ends the session.
    func loadBids() async {
        guard let id = serviceRequestId else { return }
        do {
            let fetched = try await bidRepository.fetchBids(serviceRequestId: id)
            if let accepted = fetched.first(where: { $0.status == .accepted }) {
                self.acceptedBid = accepted
                self.bids = fetched.filter { $0.status == .pending }
                stopSearching()
                return
            }
            self.bids = fetched.filter { $0.status == .pending }
            if !self.bids.isEmpty {
                // Offers arrived — stop the "no offers yet" countdown.
                countdownTask?.cancel()
                countdownTask = nil
                showRetryPrompt = false
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func acceptBid(_ bid: Bid) async -> Bool {
        guard let bidId = bid.id else { return false }
        isLoading = true
        errorMessage = nil
        do {
            try await bidRepository.acceptBid(bidId: bidId)
            await loadBids()
            if acceptedBid == nil { acceptedBid = bid }
            stopSearching()
            isLoading = false
            return true
        } catch {
            // e.g. "Saldo tidak cukup" surfaced from accept_bid.
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func rejectBid(_ bid: Bid) async {
        guard let bidId = bid.id else { return }
        do {
            try await bidRepository.updateBidStatus(bidId: bidId, status: .rejected)
            await loadBids()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Abandon the search: cancel the request so it leaves the bengkel feed.
    func cancelSearch() async {
        if let id = serviceRequestId {
            let update = ServiceRequestStatusUpdate(
                status: ServiceRequestStatus.cancelled.rawValue,
                mechanicNotes: nil,
                updatedAt: Self.isoNow()
            )
            try? await serviceRequestRepository.updateStatus(requestId: id, payload: update)
        }
        stopSearching()
        shouldDismiss = true
    }

    func retrySearch() {
        showRetryPrompt = false
        startCountdown()
    }

    // MARK: - Countdown

    private func startCountdown() {
        countdownTask?.cancel()
        guard bids.isEmpty, acceptedBid == nil else { return }
        searchSecondsRemaining = searchTimeoutSeconds
        // A Task started from a @MainActor context runs its body on the MainActor,
        // so the @Published reads/writes below are safe without hopping actors.
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while self.searchSecondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self.searchSecondsRemaining -= 1
            }
            if Task.isCancelled { return }
            if self.bids.isEmpty && self.acceptedBid == nil {
                self.showRetryPrompt = true
            }
        }
    }

    private func stopSearching() {
        isSearching = false
        searchSecondsRemaining = 0
        showRetryPrompt = false
        countdownTask?.cancel()
        countdownTask = nil
        stopRealtime()
    }

    // MARK: - Realtime (the one sanctioned direct-`supabase` use — see CLAUDE.md)

    private func startRealtime() {
        stopRealtime()
        guard let id = serviceRequestId else { return }
        let channel = supabase.channel("bids_\(id)")
        self.realtimeChannel = channel
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "bids",
            filter: "service_request_id=eq.\(id)"
        )
        realtimeTask = Task { [weak self] in
            await channel.subscribe()
            await self?.loadBids()           // cold-start reconcile after subscribe
            for await _ in changes {
                await self?.loadBids()
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

    private static func isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }
}
