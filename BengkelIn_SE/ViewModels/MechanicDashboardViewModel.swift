//
//  MechanicDashboardViewModel.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

// Drives the mechanic's "Pekerjaan Aktif" feed. Mirrors the bengkel's arrived-order
// experience: watches the mechanic's assigned jobs in realtime, and when a brand-new
// assignment lands it fires a local notification and pops an in-app modal.
@MainActor
class MechanicDashboardViewModel: ObservableObject {
    @Published var jobs: [NearbyOrder] = []
    // Drives the in-app modal that pops when the provider dispatches a new job.
    @Published var newAssignmentAlert: NearbyOrder?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let assignmentRepository = MechanicAssignmentRepository()
    private let authService = AuthService()
    private let notificationService = NotificationService()

    private var channel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []
    private var knownJobIds: Set<String> = []
    private var didInitialLoad = false
    private var hasStarted = false
    private var myUid: String?

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            let client = supabase
            Task { await client.removeChannel(channel) }
        }
    }

    func start() async {
        if hasStarted { return }
        hasStarted = true
        isLoading = true
        notificationService.requestAuthorization()
        if let uid = try? await authService.currentUID() { myUid = uid }
        await loadJobs()
        subscribe()
        isLoading = false
    }

    // Realtime sockets can die while backgrounded; reload + resubscribe on foreground.
    func refreshOnForeground() async {
        guard hasStarted else { return }
        await loadJobs()
        subscribe()
    }

    func stop() {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        if let channel = channel {
            Task { await supabase.removeChannel(channel) }
            self.channel = nil
        }
    }

    private func loadJobs() async {
        guard let uid = myUid else { return }
        do {
            let fetched = try await assignmentRepository.fetchAssignedJobs(mechanicId: uid)
            // Alert + notify for any job not seen before — but seed quietly on first load
            // so pre-existing assignments don't trigger a burst of notifications.
            if didInitialLoad {
                for job in fetched where !knownJobIds.contains(job.id) {
                    newAssignmentAlert = job
                    notificationService.notifyNewOrder(
                        title: "Pekerjaan Baru",
                        body: "Anda ditugaskan: \(job.serviceType ?? job.description ?? "servis")"
                    )
                }
            }
            knownJobIds = Set(fetched.map { $0.id })
            didInitialLoad = true
            self.jobs = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func subscribe() {
        stop()
        guard let uid = myUid else { return }
        let channel = supabase.channel("mechanic-jobs-\(uid)")
        self.channel = channel

        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "service_requests",
            filter: "mechanic_id=eq.\(uid)"
        )

        realtimeReaderTasks.append(Task { [weak self] in
            await channel.subscribe()
            // Cold-start reconcile: the first events can arrive during the subscribe
            // handshake and be missed, so refetch once subscribed.
            await self?.loadJobs()
            for await _ in stream { await self?.loadJobs() }
        })
    }
}
