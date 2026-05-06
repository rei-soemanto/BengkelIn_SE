//
//  MechanicViewModel.swift
//  BengkelIn_SE
//
//  Created for Mechanic feature on 05/05/26.
//  Phase 1 Backend Migration — Live Supabase Integration on 07/05/26.
//

import SwiftUI
import Combine
import Supabase

// MARK: - MechanicViewModel
// Handles: fetching available bengkels, creating service requests,
// fetching the user's active requests, accepting requests (provider-side),
// updating request status, and subscribing to realtime status changes.

@MainActor
class MechanicViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// Available bengkels (verified shops) for the customer to pick from.
    @Published var availableBengkels: [Bengkel] = []
    
    /// The current user's service requests (customer-facing).
    @Published var myServiceRequests: [ServiceRequest] = []
    
    /// Incoming pending requests targeted at the provider's bengkel (provider-facing).
    @Published var incomingRequests: [ServiceRequest] = []
    
    /// The single active/in-progress request being tracked (for realtime).
    @Published var activeRequest: ServiceRequest?
    
    /// Loading, error, and success states — the UI should always reflect these.
    @Published var isLoading = false
    @Published var isFetchingBengkels = false
    @Published var isCreatingRequest = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Realtime
    
    /// Holds the active Realtime channel subscription so it can be torn down.
    private var realtimeChannel: RealtimeChannelV2?
    /// Background task that listens for realtime changes.
    private var realtimeTask: Task<Void, Never>?
    
    // MARK: - Lifecycle
    
    deinit {
        // Tear down the realtime subscription to prevent leaks.
        // Because deinit runs off the MainActor, we capture what we need.
        let channel = realtimeChannel
        let task = realtimeTask
        task?.cancel()
        Task { [channel] in
            if let channel = channel {
                await supabase.removeChannel(channel)
            }
        }
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 1. Fetch Available Bengkels (Customer-Side)
    // ──────────────────────────────────────────────────────
    
    /// Fetches all verified bengkels from the `bengkels` table.
    /// RLS Note: The `bengkels` table should have a SELECT policy that allows
    /// authenticated users to read rows where `status = 'Verified'`.
    func fetchAvailableBengkels() async {
        isFetchingBengkels = true
        errorMessage = nil
        
        do {
            let bengkels: [Bengkel] = try await supabase.from("bengkels")
                .select()
                .eq("status", value: "Verified")
                .order("average_rating", ascending: false)
                .execute()
                .value
            
            self.availableBengkels = bengkels
        } catch {
            self.errorMessage = "Failed to load available bengkels: \(error.localizedDescription)"
            print("[MechanicVM] fetchAvailableBengkels error: \(error)")
        }
        
        isFetchingBengkels = false
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 2. Create Service Request (Customer-Side)
    // ──────────────────────────────────────────────────────
    
    /// Creates a new service request linked to the authenticated user, a vehicle, and a bengkel.
    /// - Parameters:
    ///   - vehicleId: The UUID of the customer's selected vehicle.
    ///   - bengkelId: The UUID of the chosen bengkel.
    ///   - serviceType: Free-text service type (e.g. "Flat Tire Repair").
    ///   - description: Optional customer notes.
    ///   - isEmergency: Whether this is a roadside assistance request.
    ///   - location: Human-readable location string.
    ///   - latitude: GPS latitude of the customer.
    ///   - longitude: GPS longitude of the customer.
    ///   - estimatedPrice: Optional estimated cost.
    /// - Returns: `true` if the request was created successfully.
    func createServiceRequest(
        vehicleId: String,
        bengkelId: String,
        serviceType: String,
        description: String? = nil,
        isEmergency: Bool = false,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        estimatedPrice: Double? = nil
    ) async -> Bool {
        isCreatingRequest = true
        errorMessage = nil
        successMessage = nil
        
        // Step 1: Validate authenticated session
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "You must be logged in to create a service request."
            isCreatingRequest = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        
        // Step 2: Build the insert payload (DB manages id, created_at, updated_at)
        let insertPayload = ServiceRequestInsert(
            customerId: uid,
            vehicleId: vehicleId,
            bengkelId: bengkelId,
            serviceType: serviceType,
            description: description,
            status: ServiceRequestStatus.pending.rawValue,
            isEmergency: isEmergency,
            location: location,
            latitude: latitude,
            longitude: longitude,
            estimatedPrice: estimatedPrice
        )
        
        // Step 3: Insert
        do {
            let created: ServiceRequest = try await supabase.from("service_requests")
                .insert(insertPayload)
                .select()
                .single()
                .execute()
                .value
            
            self.myServiceRequests.insert(created, at: 0)
            self.activeRequest = created
            self.successMessage = "Service request submitted! Waiting for bengkel confirmation."
            
            // Auto-subscribe to realtime updates for this new request
            if let requestId = created.id {
                subscribeToRequestUpdates(requestId: requestId, userId: uid)
            }
            
            isCreatingRequest = false
            return true
        } catch {
            self.errorMessage = "Failed to create service request: \(error.localizedDescription)"
            print("[MechanicVM] createServiceRequest error: \(error)")
            isCreatingRequest = false
            return false
        }
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 3. Fetch My Service Requests (Customer-Side)
    // ──────────────────────────────────────────────────────
    
    /// Fetches all service requests created by the authenticated user.
    /// RLS Note: The SELECT policy on `service_requests` should restrict
    /// rows to `auth.uid() = customer_id`.
    func fetchMyServiceRequests() async {
        isLoading = true
        errorMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "You must be logged in to view your requests."
            isLoading = false
            return
        }
        let uid = session.user.id.uuidString.lowercased()
        
        do {
            let requests: [ServiceRequest] = try await supabase.from("service_requests")
                .select()
                .eq("customer_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.myServiceRequests = requests
            
            // Set the first non-terminal request as the active one
            self.activeRequest = requests.first(where: {
                $0.status == .pending || $0.status == .accepted || $0.status == .inProgress
            })
            
        } catch {
            self.errorMessage = "Failed to load your service requests: \(error.localizedDescription)"
            print("[MechanicVM] fetchMyServiceRequests error: \(error)")
        }
        
        isLoading = false
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 4. Fetch Incoming Requests (Provider/Bengkel-Side)
    // ──────────────────────────────────────────────────────
    
    /// Fetches pending service requests targeted at a specific bengkel.
    /// Called by the provider dashboard to show incoming job offers.
    /// - Parameter bengkelId: The ID of the provider's bengkel.
    func fetchIncomingRequests(bengkelId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let requests: [ServiceRequest] = try await supabase.from("service_requests")
                .select()
                .eq("bengkel_id", value: bengkelId)
                .in("status", values: [
                    ServiceRequestStatus.pending.rawValue,
                    ServiceRequestStatus.accepted.rawValue,
                    ServiceRequestStatus.inProgress.rawValue
                ])
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.incomingRequests = requests
        } catch {
            self.errorMessage = "Failed to load incoming requests: \(error.localizedDescription)"
            print("[MechanicVM] fetchIncomingRequests error: \(error)")
        }
        
        isLoading = false
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 5. Accept Service Request (Provider-Side)
    // ──────────────────────────────────────────────────────
    
    /// Accepts a pending service request by setting its status to `accepted`.
    /// - Parameter requestId: The UUID of the service request to accept.
    /// - Returns: `true` on success.
    func acceptServiceRequest(requestId: String) async -> Bool {
        return await updateRequestStatus(
            requestId: requestId,
            newStatus: .accepted,
            notes: nil,
            successMsg: "Request accepted! Customer has been notified."
        )
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 6. Start Work on Request (Mechanic-Side)
    // ──────────────────────────────────────────────────────
    
    /// Transitions a service request to `in_progress`.
    /// - Parameter requestId: The UUID of the service request.
    /// - Returns: `true` on success.
    func startWork(requestId: String) async -> Bool {
        return await updateRequestStatus(
            requestId: requestId,
            newStatus: .inProgress,
            notes: nil,
            successMsg: "Job started. Work in progress..."
        )
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 7. Complete Service Request (Mechanic-Side)
    // ──────────────────────────────────────────────────────
    
    /// Marks a service request as `completed`. In production,
    /// this is where you'd also handle Supabase Storage photo upload.
    /// - Parameters:
    ///   - requestId: The UUID of the service request.
    ///   - notes: Optional completion notes from the mechanic.
    /// - Returns: `true` on success.
    func completeServiceRequest(requestId: String, notes: String? = nil) async -> Bool {
        let success = await updateRequestStatus(
            requestId: requestId,
            newStatus: .completed,
            notes: notes,
            successMsg: "Job completed successfully! Proof uploaded."
        )
        
        if success {
            // Remove from active lists
            withAnimation(.easeInOut) {
                self.incomingRequests.removeAll { $0.id == requestId }
                if self.activeRequest?.id == requestId {
                    self.activeRequest = nil
                }
            }
        }
        
        return success
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 8. Cancel Service Request
    // ──────────────────────────────────────────────────────
    
    /// Cancels a service request. Can be called by either party.
    /// - Parameter requestId: The UUID of the service request.
    /// - Returns: `true` on success.
    func cancelServiceRequest(requestId: String) async -> Bool {
        let success = await updateRequestStatus(
            requestId: requestId,
            newStatus: .cancelled,
            notes: nil,
            successMsg: "Service request cancelled."
        )
        
        if success {
            withAnimation(.easeInOut) {
                self.myServiceRequests.removeAll { $0.id == requestId }
                self.incomingRequests.removeAll { $0.id == requestId }
                if self.activeRequest?.id == requestId {
                    self.activeRequest = nil
                }
            }
        }
        
        return success
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - 9. Realtime Subscription (Scoped to User)
    // ──────────────────────────────────────────────────────
    
    /// Subscribes to realtime Postgres changes on the `service_requests` table,
    /// filtered to a specific request ID. This prevents data leaks from other users' rows.
    ///
    /// - Parameters:
    ///   - requestId: The service request ID to monitor.
    ///   - userId: The authenticated user's ID (used for channel naming/scoping).
    func subscribeToRequestUpdates(requestId: String, userId: String) {
        // Tear down any existing subscription first
        teardownRealtime()
        
        let channelName = "service_request_\(requestId)"
        
        let channel = supabase.channel(channelName)
        self.realtimeChannel = channel
        
        // Listen for UPDATE events on service_requests filtered by ID
        let changes = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "service_requests",
            filter: "id=eq.\(requestId)"
        )
        
        self.realtimeTask = Task { [weak self] in
            // Subscribe to the channel
            await channel.subscribe()
            
            // Listen for changes
            for await change in changes {
                guard let self = self, !Task.isCancelled else { break }
                
                do {
                    let updatedRecord = try change.decodeRecord(as: ServiceRequest.self, decoder: ServiceRequest.decoder)
                    
                    await MainActor.run {
                        // Update the active request
                        self.activeRequest = updatedRecord
                        
                        // Update in the local arrays
                        if let idx = self.myServiceRequests.firstIndex(where: { $0.id == requestId }) {
                            self.myServiceRequests[idx] = updatedRecord
                        }
                        if let idx = self.incomingRequests.firstIndex(where: { $0.id == requestId }) {
                            self.incomingRequests[idx] = updatedRecord
                        }
                        
                        print("[MechanicVM] Realtime update: request \(requestId) → \(updatedRecord.status.rawValue)")
                    }
                } catch {
                    print("[MechanicVM] Realtime decode error: \(error)")
                }
            }
        }
    }
    
    /// Tears down the active realtime channel subscription.
    func teardownRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
        
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
            realtimeChannel = nil
        }
    }
    
    // ──────────────────────────────────────────────────────
    // MARK: - Private: Generic Status Update
    // ──────────────────────────────────────────────────────
    
    /// Centralized, defensive status updater. All status transitions route through here.
    /// - Parameters:
    ///   - requestId: The UUID of the service request to update.
    ///   - newStatus: The target status.
    ///   - notes: Optional mechanic notes to attach.
    ///   - successMsg: Message to publish on `successMessage` if the update succeeds.
    /// - Returns: `true` on success.
    private func updateRequestStatus(
        requestId: String,
        newStatus: ServiceRequestStatus,
        notes: String?,
        successMsg: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let updatePayload = ServiceRequestStatusUpdate(
            status: newStatus.rawValue,
            mechanicNotes: notes,
            updatedAt: isoFormatter.string(from: Date())
        )
        
        do {
            try await supabase.from("service_requests")
                .update(updatePayload)
                .eq("id", value: requestId)
                .execute()
            
            self.successMessage = successMsg
            isLoading = false
            return true
        } catch {
            self.errorMessage = "Failed to update request: \(error.localizedDescription)"
            print("[MechanicVM] updateRequestStatus error: \(error)")
            isLoading = false
            return false
        }
    }
}

// MARK: - Custom Decoder for ServiceRequest (handles Supabase date formats)

extension ServiceRequest {
    /// A JSONDecoder configured for Supabase's default ISO 8601 date format.
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            // Fallback: try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }
}
