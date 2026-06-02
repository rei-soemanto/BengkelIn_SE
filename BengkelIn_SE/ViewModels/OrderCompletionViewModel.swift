//
//  OrderCompletionViewModel.swift
//  BengkelIn_SE
//
//  Ported from MbengkelIn (Eugene's completion feature). Dual-confirm completion
//  with a mandatory provider proof photo, live via realtime on the request row.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class OrderCompletionViewModel: ObservableObject {
    private let authService = AuthService()
    @Published var order: ServiceRequest?
    @Published var isLoading = false
    @Published var errorMessage: String?

    let requestId: String
    let isCustomer: Bool

    private let serviceRequestRepository = ServiceRequestRepository()
    private let storageService = StorageService()
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []

    nonisolated init(requestId: String, isCustomer: Bool) {
        self.requestId = requestId
        self.isCustomer = isCustomer
    }

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    var status: ServiceRequestStatus { order?.status ?? .accepted }
    var isFinished: Bool { status == .completed || status == .cancelled }
    var mySideCompleted: Bool {
        isCustomer ? (order?.customerCompleted ?? false) : (order?.providerCompleted ?? false)
    }

    func start() async {
        await refresh()
        startRealtimeSubscription()
    }

    func refresh() async {
        do {
            self.order = try await serviceRequestRepository.fetchById(id: requestId)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func startRealtimeSubscription() {
        stopRealtimeSubscription()
        let channel = supabase.channel("order-completion-\(requestId)")
        self.realtimeChannel = channel
        let stream = channel.postgresChange(
            AnyAction.self, schema: "public", table: "service_requests", filter: "id=eq.\(requestId)"
        )
        realtimeReaderTasks.append(Task { [weak self] in
            guard let self = self else { return }
            await channel.subscribe()
            for await _ in stream { await self.refresh() }
        })
    }

    func stopRealtimeSubscription() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = realtimeChannel {
            Task { await supabase.removeChannel(channel) }
            realtimeChannel = nil
        }
    }

    func markCompleted(photoData: Data? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            var photoUrl: String? = nil
            if let photoData {
                let session = try await authService.getCurrentSession()
                let uid = session.user.id.uuidString.lowercased()
                photoUrl = try await storageService.uploadOrderPhoto(uid: uid, data: photoData)
            }
            self.order = try await serviceRequestRepository.markOrderCompleted(
                requestId: requestId, completionPhotoUrl: photoUrl
            )
        } catch {
            // e.g. "Foto penyelesaian wajib dilampirkan" surfaced from the RPC.
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
