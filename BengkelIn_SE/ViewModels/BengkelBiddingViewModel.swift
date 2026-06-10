//
//  BengkelBiddingViewModel.swift
//  BengkelIn
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class BengkelBiddingViewModel: ObservableObject {
    private let authService = AuthService()
    @Published var orders: [NearbyOrder] = []
    @Published var myBengkel: Bengkel?
    @Published var myPendingBids: [Bid] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    @Published var newOrderAlert: NearbyOrder?
    @Published var lostBidAlert: String?
    @Published var expiredBidAlert: String?
    @Published var activeBengkelOrder: NearbyOrder?
    @Published var rejectedBidAlert: String?
    @Published var orderUnavailableAlert: String?
    @Published var myRejectedBids: [Bid] = []
    @Published var hasMechanics = true

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []
    private let orderRepository = OrderRepository()
    private let bengkelRepository = BengkelRepository()
    private let bidRepository = BidRepository()
    private let biddingService = BiddingService()
    private let mechanicRepository = MechanicRepository()
    private let notificationService = NotificationService()
    private var knownOrderIds: Set<String> = []
    private var bidStatusById: [String: String] = [:]
    private var didInitialLoad = false
    private var hasStarted = false
    private var providerUid: String?

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            let client = supabase
            Task {
                await client.removeChannel(channel)
            }
        }
    }

    func start() async {
        let uid = try? await authService.currentUID()
        guard let uid else { reset(); return }
        if hasStarted, uid == providerUid { return }
        reset()
        hasStarted = true
        providerUid = uid
        isLoading = true
        errorMessage = nil
        notificationService.requestAuthorization()
        do {
            self.myBengkel = try await bengkelRepository.fetchBengkel(providerUid: uid)
        } catch {
            if !(error is CancellationError) {
                self.errorMessage = error.localizedDescription
            }
            isLoading = false
            hasStarted = false
            providerUid = nil
            return
        }
        await loadOrders()
        startRealtimeSubscription()
        isLoading = false
    }

    func reset() {
        stopRealtimeSubscription()
        hasStarted = false
        providerUid = nil
        didInitialLoad = false
        knownOrderIds = []
        bidStatusById = [:]
        orders = []
        myBengkel = nil
        myPendingBids = []
        myRejectedBids = []
        newOrderAlert = nil
        lostBidAlert = nil
        expiredBidAlert = nil
        rejectedBidAlert = nil
        orderUnavailableAlert = nil
        activeBengkelOrder = nil
    }

    func refreshOnForeground() async {
        guard hasStarted else { await start(); return }
        print("[BengkelRT] foreground refresh + resubscribe")
        await loadOrders()
        startRealtimeSubscription()
    }

    func startRealtimeSubscription() {
        stopRealtimeSubscription()
        guard let uid = providerUid else { return }

        let channel = supabase.channel("bengkel-bids-\(uid)")
        self.realtimeChannel = channel

        let bidsStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "bids",
            filter: "provider_uid=eq.\(uid)"
        )

        let serviceRequestStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests"
        )

        realtimeReaderTasks.append(Task { [weak self] in
            guard let self = self else { return }
            print("[BengkelRT] subscribing channel bengkel-bids-\(uid)")
            await channel.subscribe()
            print("[BengkelRT] channel subscribed")
            await self.loadOrders()

            Task { [weak self] in
                for await _ in bidsStream {
                    print("[BengkelRT] bids change received")
                    await self?.loadOrders()
                }
            }

            Task { [weak self] in
                for await _ in serviceRequestStream {
                    print("[BengkelRT] service_requests change received")
                    await self?.loadOrders()
                }
            }
        })
    }

    func stopRealtimeSubscription() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
            realtimeChannel = nil
        }
    }

    func loadOrders() async {
        guard let bengkel = myBengkel, let bengkelId = bengkel.id else { return }
        errorMessage = nil
        if let roster = try? await mechanicRepository.fetchRoster() {
            hasMechanics = roster.contains { $0.isAccepted }
        }
        guard hasMechanics else {
            orders = []
            myPendingBids = []
            myRejectedBids = []
            newOrderAlert = nil
            knownOrderIds = []
            return
        }
        do {
            let nearbyOrders = try await biddingService.fetchOrdersForMechanic(
                latitude: bengkel.latitude,
                longitude: bengkel.longitude,
                radiusMeters: 5000
            )

            let allMyBids = try await bidRepository.fetchBidsForBengkel(bengkelId: bengkelId)

            if didInitialLoad {
                for bid in allMyBids where bidStatusById[bid.id] == "pending" {
                    switch bid.status.lowercased() {
                    case "accepted":
                        notificationService.notifyNewOrder(
                            title: "Tawaran diterima!",
                            body: "Pelanggan menerima tawaran Anda. Order otomatis dibuka."
                        )
                        if self.activeBengkelOrder == nil,
                           let order = try? await self.orderRepository.fetchOrder(id: bid.serviceRequestId) {
                            self.activeBengkelOrder = order
                        }
                    case "autorejected":
                        notificationService.notifyNewOrder(
                            title: "Order diambil bengkel lain",
                            body: "Pelanggan memilih tawaran bengkel lain untuk order ini."
                        )
                        self.lostBidAlert = "Pelanggan memilih tawaran bengkel lain. Tawaran Anda tidak terpilih."
                    case "expired":
                        notificationService.notifyNewOrder(
                            title: "Waktu order habis",
                            body: "Pelanggan tidak menanggapi tepat waktu. Order kedaluwarsa."
                        )
                        self.expiredBidAlert = "Waktu order telah habis. Order kedaluwarsa karena pelanggan tidak menanggapi tepat waktu."
                    case "rejected":
                        notificationService.notifyNewOrder(
                            title: "Tawaran ditolak",
                            body: "Pelanggan menolak tawaran Anda. Anda bisa menawar ulang dengan harga lain."
                        )
                        self.rejectedBidAlert = "Pelanggan menolak tawaran Anda. Order masih terbuka — silakan ajukan harga lain."
                    default:
                        break
                    }
                }
            }
            bidStatusById = Dictionary(allMyBids.map { ($0.id, $0.status.lowercased()) }, uniquingKeysWith: { _, new in new })

            let terminalRequestIds = Set(allMyBids.filter { ["autorejected", "expired"].contains($0.status.lowercased()) }.map { $0.serviceRequestId })
            self.myPendingBids = allMyBids.filter { $0.status.lowercased() == "pending" }
            self.myRejectedBids = allMyBids.filter { $0.status.lowercased() == "rejected" }

            let filteredOrders = nearbyOrders.filter { !terminalRequestIds.contains($0.id) }

            let currentIds = Set(filteredOrders.map { $0.id })
            if didInitialLoad {
                for order in filteredOrders where !knownOrderIds.contains(order.id) {
                    let meters = Int(order.distanceM ?? 0)
                    notificationService.notifyNewOrder(
                        title: "Order baru di sekitar!",
                        body: "\(order.description ?? order.serviceType ?? "Permintaan servis") • \(meters) m"
                    )
                    self.newOrderAlert = order
                }
            }
            knownOrderIds = currentIds
            didInitialLoad = true

            self.orders = filteredOrders
            if let alert = self.newOrderAlert, !currentIds.contains(alert.id) {
                self.newOrderAlert = nil
            }
            print("[BengkelRT] loadOrders -> \(filteredOrders.count) nearby order(s), didInitialLoad=\(didInitialLoad)")
        } catch {
            print("[BengkelRT] loadOrders error: \(error.localizedDescription)")
            if !(error is CancellationError) {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func placeBid(order: NearbyOrder, price: Int, notes: String) async {
        guard let bengkel = myBengkel, let bengkelId = bengkel.id else { return }
        if let roster = try? await mechanicRepository.fetchRoster() {
            hasMechanics = roster.contains { $0.isAccepted }
        }
        guard hasMechanics else {
            self.errorMessage = "Tambahkan mekanik terlebih dahulu sebelum mengambil order."
            return
        }
        guard let latest = try? await orderRepository.fetchOrder(id: order.id),
              latest.status == "pending", latest.bengkelId == nil else {
            self.errorMessage = "Order sudah tidak tersedia."
            self.orderUnavailableAlert = "Order ini sudah dibatalkan atau diambil bengkel lain. Order telah ditutup."
            await loadOrders()
            return
        }
        let floor = order.price ?? 0
        guard price >= floor, price > 0 else {
            self.errorMessage = "Tawaran tidak boleh di bawah harga pelanggan (Rp\(floor))."
            return
        }
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
            self.successMessage = "Tawaran terkirim. Menunggu pelanggan menerima."
            await loadOrders()
        } catch {
            if !(error is CancellationError) {
                self.errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func handleExpiredOrder(_ order: NearbyOrder) async {
        orders.removeAll { $0.id == order.id }
        knownOrderIds.remove(order.id)
        if let bid = myPendingBids.first(where: { $0.serviceRequestId == order.id }) {
            await expireBid(bid)
        }
    }

    func expireBid(_ bid: Bid) async {
        do {
            try await bidRepository.updateStatus(bidId: bid.id, status: "Expired")
            await loadOrders()
        } catch {
            if !(error is CancellationError) {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func rejectBid(_ bid: Bid) async {
        do {
            try await bidRepository.updateStatus(bidId: bid.id, status: "Rejected")
            await loadOrders()
        } catch {
            if !(error is CancellationError) {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
