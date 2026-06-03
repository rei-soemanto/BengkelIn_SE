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
    // Separate channel for the per-mechanic broadcast topic. postgres_changes can't
    // tell a reassigned-away mechanic they were replaced (they lose RLS SELECT on the
    // row the instant it's reassigned), so assign_mechanic broadcasts to this topic.
    private var broadcastChannel: RealtimeChannelV2?
    private var realtimeReaderTasks: [Task<Void, Never>] = []
    // id -> assignment token (assigned_at). Keyed on the assignment timestamp, not
    // just the id, so a re-assignment (which bumps assigned_at) re-notifies even
    // though the request id is unchanged — a reassigned-away mechanic never sees
    // the job leave (RLS), so an id-only set would stay stale and miss the return.
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
        // Already running for this exact user — no-op. A DIFFERENT uid means the
        // account was switched (logout → login as another mechanic) without killing
        // the app, which keeps this app-level @StateObject — and its old subscription
        // filtered on the previous mechanic's id — alive. Tear down and re-subscribe
        // as the new user, else assignments to the new mechanic are never delivered.
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

    // Detach from the current identity: used on logout and when the signed-in user
    // isn't a mechanic, so a stale subscription can't keep firing the old user's alerts.
    func reset() {
        stop()
        hasStarted = false
        myUid = nil
        knownAssignments = [:]
        didInitialLoad = false
        newAssignmentAlert = nil
        jobs = []
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
        if let broadcastChannel = broadcastChannel {
            Task { await supabase.removeChannel(broadcastChannel) }
            self.broadcastChannel = nil
        }
    }

    private func loadJobs() async {
        guard let uid = myUid else { return }
        do {
            let fetched = try await assignmentRepository.fetchAssignedJobs(mechanicId: uid)
            // Alert + notify for any job not seen before — but seed quietly on first load
            // so pre-existing assignments don't trigger a burst of notifications.
            if didInitialLoad {
                for job in fetched where knownAssignments[job.id] != (job.assignedAt ?? job.id) {
                    newAssignmentAlert = job
                    notificationService.notifyNewOrder(
                        title: "Pekerjaan Baru",
                        body: "Anda ditugaskan: \(job.serviceType ?? job.description ?? "servis")"
                    )
                }
            }
            knownAssignments = Dictionary(
                fetched.map { ($0.id, $0.assignedAt ?? $0.id) },
                uniquingKeysWith: { _, latest in latest }
            )
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
            for await _ in stream {
                await self?.loadJobs()
                // This always-on subscription is the single source of truth for live
                // service_requests changes on this mechanic. Other screens (history) ride
                // it via NotificationCenter rather than opening a duplicate postgres_changes
                // subscription on the same filter, which Realtime delivers to unreliably.
                NotificationCenter.default.post(name: .mechanicOrdersChanged, object: nil)
            }
        })

        subscribeReassignBroadcast(uid: uid)
    }

    private func subscribeReassignBroadcast(uid: String) {
        let channel = supabase.channel("mechanic:\(uid)")
        self.broadcastChannel = channel
        let stream = channel.broadcastStream(event: "reassigned_away")
        realtimeReaderTasks.append(Task { [weak self] in
            await channel.subscribe()
            for await message in stream { await self?.handleReassignedAway(message) }
        })
    }

    // The provider replaced this mechanic on an order. Tell them, drop the stale job
    // from the active feed, and let other screens (history, route) react.
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
    // Posted (main thread) when the signed-in mechanic is replaced on an order.
    // object is the affected request id (String). Screens with their own order
    // lists/state observe this to self-heal, since RLS blocks the realtime row update.
    static let mechanicReassignedAway = Notification.Name("mechanicReassignedAway")

    // Posted whenever a live service_requests change lands for the signed-in mechanic
    // (assigned, completed, cancelled). Screens with their own order lists observe this
    // to refresh, instead of opening a second postgres_changes subscription.
    static let mechanicOrdersChanged = Notification.Name("mechanicOrdersChanged")
}
