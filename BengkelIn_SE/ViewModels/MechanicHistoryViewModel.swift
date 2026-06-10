//
//  MechanicHistoryViewModel.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 03/06/26.
//

import SwiftUI
import Combine
import Supabase

// The mechanic's "Riwayat Pesanan": every order ever dispatched to them — active
// (accepted), completed, or cancelled. Mirrors BengkelHistoryViewModel but scoped
// to mechanic_id instead of bengkel_id.
@MainActor
class MechanicHistoryViewModel: ObservableObject {
    @Published var orders: [NearbyOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var detailOrder: NearbyOrder?
    @Published var reportedOrderIds: Set<String> = []

    private let orderRepository = OrderRepository()
    private let behaviorReportRepository = BehaviorReportRepository()
    private let authService = AuthService()
    private var mechanicId: String?
    private var ordersChangedObserver: NSObjectProtocol?
    private var reassignObserver: NSObjectProtocol?

    init() {
        // Live sync rides the app-level dashboard subscription (the single source of
        // truth for this mechanic's service_requests changes) instead of opening a
        // second postgres_changes subscription on the same filter, which Realtime
        // delivers to unreliably. A live change → refetch the full history.
        ordersChangedObserver = NotificationCenter.default.addObserver(
            forName: .mechanicOrdersChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reload() }
        }
        // Reassigned-away events can't come through that path (RLS hides the row),
        // so the broadcast watcher posts this; drop the order the moment we hear it.
        reassignObserver = NotificationCenter.default.addObserver(
            forName: .mechanicReassignedAway, object: nil, queue: .main
        ) { [weak self] note in
            guard let id = note.object as? String else { return }
            Task { @MainActor in self?.orders.removeAll { $0.id == id } }
        }
    }

    deinit {
        if let ordersChangedObserver { NotificationCenter.default.removeObserver(ordersChangedObserver) }
        if let reassignObserver { NotificationCenter.default.removeObserver(reassignObserver) }
    }

    func loadOrders() async {
        isLoading = true
        errorMessage = nil
        do {
            let uid = try await authService.currentUID()
            self.mechanicId = uid
            let fetched = try await orderRepository.fetchMechanicOrders(mechanicId: uid)
            self.orders = fetched.sorted(by: Self.isOrderedBefore)
            if let reported = try? await behaviorReportRepository.fetchReportedRequestIds(reporterId: uid) {
                self.reportedOrderIds = Set(reported)
            }
        } catch {
            if !(error is CancellationError) {
                self.errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func markReported(_ orderId: String) {
        reportedOrderIds.insert(orderId)
    }

    func select(_ order: NearbyOrder) {
        self.detailOrder = order
    }

    private func reload() async {
        guard let mechanicId else { return }
        if let fetched = try? await orderRepository.fetchMechanicOrders(mechanicId: mechanicId) {
            self.orders = fetched.sorted(by: Self.isOrderedBefore)
        }
    }

    private static func isOrderedBefore(_ lhs: NearbyOrder, _ rhs: NearbyOrder) -> Bool {
        let lp = priority(lhs.status)
        let rp = priority(rhs.status)
        if lp != rp { return lp < rp }
        return (lhs.createdAt ?? "") > (rhs.createdAt ?? "")
    }

    private static func priority(_ status: String) -> Int {
        switch status {
        case "accepted": return 0
        case "pending": return 1
        default: return 2
        }
    }
}
