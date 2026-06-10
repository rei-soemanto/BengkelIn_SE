//
//  MechanicDashboardViewModel.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class MechanicDashboardViewModel: ObservableObject {
    @Published var jobs: [NearbyOrder] = []
    @Published var newAssignmentAlert: NearbyOrder?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let assignmentRepository = MechanicAssignmentRepository()
    private let authService = AuthService()
    private let notificationService = NotificationService()

    private var channel: RealtimeChannelV2?
    private var broadcastChannel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []
    private var knownAssignments: [String: String] = [:]
    private var didInitialLoad = false
    private var hasStarted = false
    private var myUid: String?

    deinit {
        realtimeReaderTasks.forEach { $0.cancel() }
        realtimeReaderTasks.removeAll()
        let client = supabase
        if let channel = channel { Task { await client.removeChannel(channel) } }
        if let broadcastChannel = broadcastChannel { Task { await client.removeChannel(broadcastChannel) } }
    }

    func start() async {
        let uid = try? await authService.currentUID()
        guard let uid else { reset(); return }
        if hasStarted, uid == myUid { return }
        reset()
        hasStarted = true
        myUid = uid
        isLoading = true
        notificationService.requestAuthorization()
        await loadJobs()
        subscribe()
        isLoading = false
    }

    func reset() {
        stop()
        hasStarted = false
        myUid = nil
        knownAssignments = [:]
        didInitialLoad = false
        newAssignmentAlert = nil
        jobs = []
    }

    func refreshOnForeground() async {
        guard hasStarted else { await start(); return }
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
        if let broadcastChannel = broadcastChannel {
            Task { await supabase.removeChannel(broadcastChannel) }
            self.broadcastChannel = nil
        }
    }

    private func loadJobs() async {
        guard let uid = myUid else { return }
        do {
            let fetched = try await assignmentRepository.fetchAssignedJobs(mechanicId: uid)
            if didInitialLoad {
                for job in fetched where knownAssignments[job.id] != (job.assignedAt ?? job.id) {
                    newAssignmentAlert = job
                    notificationService.notifyNewOrder(
                        title: "Pekerjaan Baru",
                        body: "Anda ditugaskan: \(job.serviceType ?? job.description ?? "servis")"
                    )
                }
            }
            let updated = Dictionary(
                fetched.map { ($0.id, $0.assignedAt ?? $0.id) },
                uniquingKeysWith: { _, latest in latest }
            )
            let changed = updated != knownAssignments
            knownAssignments = updated
            didInitialLoad = true
            self.jobs = fetched
            if changed {
                NotificationCenter.default.post(name: .mechanicOrdersChanged, object: nil)
            }
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
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
            await self?.loadJobs()
            for await _ in stream { await self?.loadJobs() }
        })

        subscribeMechanicBroadcast(uid: uid)
        startReconcilePoll()
    }

    private func startReconcilePoll() {
        realtimeReaderTasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if Task.isCancelled { return }
                await self?.loadJobs()
            }
        })
    }

    private func subscribeMechanicBroadcast(uid: String) {
        let channel = supabase.channel("mechanic:\(uid)")
        self.broadcastChannel = channel
        let assignedStream = channel.broadcastStream(event: "assigned")
        let reassignedStream = channel.broadcastStream(event: "reassigned_away")
        realtimeReaderTasks.append(Task { [weak self] in
            await channel.subscribe()
            for await message in assignedStream { await self?.handleAssigned(message) }
        })
        realtimeReaderTasks.append(Task { [weak self] in
            for await message in reassignedStream { await self?.handleReassignedAway(message) }
        })
    }

    private func handleAssigned(_ message: [String: AnyJSON]) async {
        await loadJobs()
    }

    private func handleReassignedAway(_ message: [String: AnyJSON]) async {
        let payload = message["payload"]?.objectValue ?? message
        guard let requestId = payload["request_id"]?.stringValue else { return }
        let serviceType = payload["service_type"]?.stringValue
        let label = (serviceType?.isEmpty == false) ? serviceType! : "servis"

        notificationService.notifyNewOrder(
            title: "Order Dialihkan",
            body: "Order \(label) telah dialihkan ke mekanik lain. Anda tidak lagi menanganinya."
        )
        jobs.removeAll { $0.id == requestId }
        knownAssignments.removeValue(forKey: requestId)
        if newAssignmentAlert?.id == requestId { newAssignmentAlert = nil }
        NotificationCenter.default.post(name: .mechanicReassignedAway, object: requestId)
    }
}

extension Notification.Name {
    static let mechanicReassignedAway = Notification.Name("mechanicReassignedAway")

    static let mechanicOrdersChanged = Notification.Name("mechanicOrdersChanged")
}
