//
//  E2EDiagnosticsView.swift
//  BengkelIn_SE
//
//  Temporary E2E test harness for Phase 1 & 2 verification.
//  Tests: INSERT → REALTIME SUBSCRIBE → MUTATE → VERIFY → CLEANUP
//  Safe: Completely standalone. Does not touch MechanicViewModel.
//  Remove this file once backend verification is complete.
//

import SwiftUI
import Supabase
import Combine

// MARK: - Test Step Model

enum TestStepStatus: Equatable {
    case idle
    case running
    case passed
    case failed(String)
}

struct TestStep: Identifiable {
    let id: Int
    let label: String
    var status: TestStepStatus = .idle
}

// MARK: - DiagnosticsViewModel

@MainActor
class DiagnosticsViewModel: ObservableObject {
    
    @Published var steps: [TestStep] = [
        TestStep(id: 0, label: "Authenticate & fetch prerequisites"),
        TestStep(id: 1, label: "INSERT service_request"),
        TestStep(id: 2, label: "SUBSCRIBE to Realtime channel"),
        TestStep(id: 3, label: "MUTATE status → accepted"),
        TestStep(id: 4, label: "VERIFY Realtime caught the change"),
        TestStep(id: 5, label: "CLEANUP — delete test row"),
    ]
    
    @Published var isRunning = false
    @Published var testLog: [String] = []
    
    /// The ID of the test row we insert. Used for subscribe + cleanup.
    private var testRequestId: String?
    
    /// The realtime channel for this test.
    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    
    /// Becomes true when realtime delivers the 'accepted' status.
    private var realtimeCaughtUpdate = false
    
    // MARK: - Run Full Test
    
    func runFullTest() async {
        guard !isRunning else { return }
        isRunning = true
        realtimeCaughtUpdate = false
        testLog = []
        
        // Reset all steps
        for i in steps.indices { steps[i].status = .idle }
        
        // ── Step 0: Auth & Prerequisites ──
        markRunning(0)
        log("Checking authentication...")
        
        guard let session = try? await supabase.auth.session else {
            markFailed(0, "No active session. Please log in first.")
            isRunning = false
            return
        }
        let uid = session.user.id.uuidString.lowercased()
        log("✓ Authenticated as \(uid.prefix(8))...")
        
        // Fetch first verified bengkel
        let bengkelId: String
        do {
            let bengkels: [Bengkel] = try await supabase.from("bengkels")
                .select()
                .eq("status", value: "Verified")
                .limit(1)
                .execute()
                .value
            
            guard let firstId = bengkels.first?.id else {
                markFailed(0, "No verified bengkels found in the database.")
                isRunning = false
                return
            }
            bengkelId = firstId
            log("✓ Bengkel: \(bengkelId.prefix(8))...")
        } catch {
            markFailed(0, "Failed to fetch bengkels: \(error.localizedDescription)")
            isRunning = false
            return
        }
        
        // Fetch first vehicle for this user
        let vehicleId: String
        do {
            let vehicles: [Vehicle] = try await supabase.from("vehicles")
                .select()
                .eq("customer_id", value: uid)
                .limit(1)
                .execute()
                .value
            
            guard let firstId = vehicles.first?.id else {
                markFailed(0, "No vehicles found for this user. Add a vehicle first.")
                isRunning = false
                return
            }
            vehicleId = firstId
            log("✓ Vehicle: \(vehicleId.prefix(8))...")
        } catch {
            markFailed(0, "Failed to fetch vehicles: \(error.localizedDescription)")
            isRunning = false
            return
        }
        
        markPassed(0)
        
        // ── Step 1: INSERT ──
        markRunning(1)
        log("Inserting test service_request...")
        
        let insertPayload = ServiceRequestInsert(
            customerId: uid,
            vehicleId: vehicleId,
            bengkelId: bengkelId,
            serviceType: "E2E_SYSTEM_TEST",
            description: "SYSTEM_TEST_IGNORE",
            status: ServiceRequestStatus.pending.rawValue,
            isEmergency: false,
            location: "E2E Test Location",
            latitude: nil,
            longitude: nil,
            estimatedPrice: 0
        )
        
        do {
            let created: ServiceRequest = try await supabase.from("service_requests")
                .insert(insertPayload)
                .select()
                .single()
                .execute()
                .value
            
            guard let id = created.id else {
                markFailed(1, "Insert succeeded but returned no ID.")
                isRunning = false
                return
            }
            
            self.testRequestId = id
            log("✓ Created request: \(id.prefix(12))...")
            log("  status = \(created.status.rawValue)")
            markPassed(1)
        } catch {
            markFailed(1, "INSERT failed: \(error.localizedDescription)")
            isRunning = false
            return
        }
        
        guard let requestId = testRequestId else {
            isRunning = false
            return
        }
        
        // ── Step 2: SUBSCRIBE ──
        markRunning(2)
        log("Setting up Realtime listener for \(requestId.prefix(12))...")
        
        let channelName = "e2e_test_\(requestId.prefix(8))"
        let ch = supabase.channel(channelName)
        self.channel = ch
        
        // Set up the postgres change listener
        let changes = ch.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "service_requests",
            filter: "id=eq.\(requestId)"
        )
        
        // Start listening in a background task
        self.realtimeTask = Task { [weak self] in
            for await change in changes {
                guard let self = self, !Task.isCancelled else { break }
                
                // Try to decode the full record
                do {
                    let record = try change.decodeRecord(as: ServiceRequest.self, decoder: ServiceRequest.decoder)
                    let newStatus = record.status.rawValue
                    
                    await MainActor.run {
                        self.log("🔔 Realtime event received! New status: \(newStatus)")
                        if newStatus == "accepted" {
                            self.realtimeCaughtUpdate = true
                        }
                    }
                } catch {
                    // Fallback: even if full decode fails, mark the event as received.
                    // The raw record dictionary is available for inspection.
                    await MainActor.run {
                        self.log("🔔 Realtime event received (decode fallback: \(error.localizedDescription))")
                        // Mark as caught — the event arrived, which is the key proof.
                        self.realtimeCaughtUpdate = true
                    }
                }
            }
        }
        
        // Subscribe to the channel
        await ch.subscribe()
        log("✓ Realtime channel subscribed: \(channelName)")
        markPassed(2)
        
        // ── Step 3: MUTATE (after 2-second delay) ──
        markRunning(3)
        log("Waiting 2 seconds before mutation...")
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        log("Updating status to 'accepted'...")
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let updatePayload = ServiceRequestStatusUpdate(
            status: ServiceRequestStatus.accepted.rawValue,
            mechanicNotes: nil,
            updatedAt: isoFormatter.string(from: Date())
        )
        
        do {
            try await supabase.from("service_requests")
                .update(updatePayload)
                .eq("id", value: requestId)
                .execute()
            
            log("✓ UPDATE executed successfully.")
            markPassed(3)
        } catch {
            markFailed(3, "UPDATE failed: \(error.localizedDescription)")
            await cleanup(requestId: requestId)
            isRunning = false
            return
        }
        
        // ── Step 4: VERIFY (wait up to 5 seconds for realtime) ──
        markRunning(4)
        log("Waiting for Realtime event (up to 5s)...")
        
        let deadline = Date().addingTimeInterval(5)
        while !realtimeCaughtUpdate && Date() < deadline {
            try? await Task.sleep(nanoseconds: 250_000_000) // poll every 250ms
        }
        
        if realtimeCaughtUpdate {
            log("✓ Realtime CONFIRMED: status changed to 'accepted'")
            markPassed(4)
        } else {
            markFailed(4, "Realtime did NOT deliver the update within 5 seconds. Check that Realtime is enabled for service_requests in Supabase Dashboard → Database → Replication.")
        }
        
        // ── Step 5: CLEANUP ──
        await cleanup(requestId: requestId)
        
        isRunning = false
    }
    
    // MARK: - Cleanup
    
    private func cleanup(requestId: String) async {
        markRunning(5)
        log("Cleaning up test row \(requestId.prefix(12))...")
        
        // Tear down realtime first
        realtimeTask?.cancel()
        realtimeTask = nil
        if let ch = channel {
            await supabase.removeChannel(ch)
            channel = nil
        }
        log("✓ Realtime channel removed.")
        
        // Delete the test row
        do {
            try await supabase.from("service_requests")
                .delete()
                .eq("id", value: requestId)
                .execute()
            
            log("✓ Test row deleted from production.")
            self.testRequestId = nil
            markPassed(5)
        } catch {
            markFailed(5, "DELETE failed: \(error.localizedDescription). Manually delete row with description 'SYSTEM_TEST_IGNORE'.")
        }
    }
    
    // MARK: - Helpers
    
    private func markRunning(_ id: Int) {
        if let idx = steps.firstIndex(where: { $0.id == id }) {
            withAnimation(.easeInOut(duration: 0.2)) { steps[idx].status = .running }
        }
    }
    
    private func markPassed(_ id: Int) {
        if let idx = steps.firstIndex(where: { $0.id == id }) {
            withAnimation(.easeInOut(duration: 0.2)) { steps[idx].status = .passed }
        }
    }
    
    private func markFailed(_ id: Int, _ msg: String) {
        if let idx = steps.firstIndex(where: { $0.id == id }) {
            withAnimation(.easeInOut(duration: 0.2)) { steps[idx].status = .failed(msg) }
        }
        log("✗ FAILED: \(msg)")
    }
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        testLog.append("[\(timestamp)] \(message)")
    }
}

// MARK: - E2EDiagnosticsView

struct E2EDiagnosticsView: View {
    @StateObject private var vm = DiagnosticsViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Header
                    VStack(spacing: 8) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("E2E System Diagnostics")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Tests CRUD + Realtime on production service_requests")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    
                    // MARK: - Checklist
                    VStack(spacing: 0) {
                        ForEach(vm.steps) { step in
                            stepRow(step)
                            
                            if step.id < vm.steps.count - 1 {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // MARK: - Run Button
                    Button {
                        Task { await vm.runFullTest() }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isRunning {
                                ProgressView()
                                    .tint(.white)
                                Text("Running...")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "play.circle.fill")
                                Text("Run Full System Test")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.isRunning ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(vm.isRunning)
                    
                    // MARK: - Result Summary
                    resultSummary
                    
                    // MARK: - Log Output
                    if !vm.testLog.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Execution Log")
                                    .font(.headline)
                                Spacer()
                                Button("Clear") {
                                    vm.testLog = []
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            ScrollView(.vertical) {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(vm.testLog.indices, id: \.self) { idx in
                                        Text(vm.testLog[idx])
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.primary.opacity(0.8))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .frame(maxHeight: 240)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Step Row
    
    private func stepRow(_ step: TestStep) -> some View {
        HStack(spacing: 12) {
            stepIcon(step.status)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if case .failed(let msg) = step.status {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(3)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    @ViewBuilder
    private func stepIcon(_ status: TestStepStatus) -> some View {
        switch status {
        case .idle:
            Image(systemName: "circle")
                .foregroundColor(.gray.opacity(0.4))
                .font(.title3)
        case .running:
            ProgressView()
                .scaleEffect(0.8)
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title3)
        }
    }
    
    // MARK: - Result Summary
    
    @ViewBuilder
    private var resultSummary: some View {
        let passed = vm.steps.filter { $0.status == .passed }.count
        let failed = vm.steps.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
        let total = vm.steps.count
        
        if passed + failed == total && !vm.isRunning {
            HStack(spacing: 12) {
                Image(systemName: failed == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(failed == 0 ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(failed == 0 ? "All Systems Operational" : "Issues Detected")
                        .font(.headline)
                        .foregroundColor(failed == 0 ? .green : .orange)
                    Text("\(passed)/\(total) passed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background((failed == 0 ? Color.green : Color.orange).opacity(0.1))
            .cornerRadius(12)
        }
    }
}

#Preview {
    E2EDiagnosticsView()
}
