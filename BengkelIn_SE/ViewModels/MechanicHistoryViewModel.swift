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
    private var channel: RealtimeChannelV2?
    private var mechanicId: String?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
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
            startRealtimeIfNeeded()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func markReported(_ orderId: String) {
        reportedOrderIds.insert(orderId)
    }

    func select(_ order: NearbyOrder) {
        self.detailOrder = order
    }

    private func startRealtimeIfNeeded() {
        guard channel == nil, let mechanicId else { return }
        let channel = supabase.channel("mechanic-history-\(mechanicId)")
        self.channel = channel
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: "mechanic_id=eq.\(mechanicId)"
        )
        realtimeReaderTasks.append(Task { [weak self] in
            await channel.subscribe()
            for await _ in stream {
                await self?.reload()
            }
        })
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
