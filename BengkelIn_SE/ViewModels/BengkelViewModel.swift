//
//  BengkelViewModel.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI
import Combine
import MapKit
import Supabase

// MARK: - Lightweight response type for incoming requests (provider dashboard)

/// A joined view of a service request with its related customer and vehicle info.
/// Used for the provider dashboard "Incoming Requests" display.
struct IncomingRequestDisplay: Identifiable {
    let id: String
    let serviceType: String
    let isEmergency: Bool
    let status: ServiceRequestStatus
    let location: String?
    let estimatedPrice: Double?
    let createdAt: Date?
}

@MainActor
class BengkelViewModel: ObservableObject {
    @Published var myBengkel: Bengkel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Provider Job State (Live — from service_requests table)
    
    /// Pending service requests targeting this provider's bengkel.
    @Published var pendingRequests: [ServiceRequest] = []
    /// The currently active (accepted/in_progress) requests.
    @Published var activeServiceRequests: [ServiceRequest] = []
    /// Today's earnings (sum of completed request estimated prices).
    @Published var todaysEarnings: Double = 0.0
    
    var pendingRequestsCount: Int { pendingRequests.count }
    var hasActiveJob: Bool { !activeServiceRequests.isEmpty }
    
    /// Fetches all service requests for this bengkel from Supabase.
    /// Separates them into pending vs. active buckets.
    func fetchServiceRequests(bengkelId: String) async {
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
            
            self.pendingRequests = requests.filter { $0.status == .pending }
            self.activeServiceRequests = requests.filter {
                $0.status == .accepted || $0.status == .inProgress
            }
        } catch {
            self.errorMessage = "Failed to load service requests: \(error.localizedDescription)"
            print("[BengkelVM] fetchServiceRequests error: \(error)")
        }
    }
    
    /// Fetches today's total earnings from completed requests.
    func fetchTodaysEarnings(bengkelId: String) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let startStr = isoFormatter.string(from: startOfDay)
        
        do {
            let completed: [ServiceRequest] = try await supabase.from("service_requests")
                .select()
                .eq("bengkel_id", value: bengkelId)
                .eq("status", value: ServiceRequestStatus.completed.rawValue)
                .gte("updated_at", value: startStr)
                .execute()
                .value
            
            self.todaysEarnings = completed.compactMap(\.estimatedPrice).reduce(0, +)
        } catch {
            print("[BengkelVM] fetchTodaysEarnings error: \(error)")
        }
    }
    
    /// Accepts a pending service request.
    func acceptJob(requestId: String) async {
        isLoading = true
        errorMessage = nil
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let update = ServiceRequestStatusUpdate(
            status: ServiceRequestStatus.accepted.rawValue,
            mechanicNotes: nil,
            updatedAt: isoFormatter.string(from: Date())
        )
        
        do {
            try await supabase.from("service_requests")
                .update(update)
                .eq("id", value: requestId)
                .execute()
            
            // Move from pending to active
            withAnimation {
                if let idx = pendingRequests.firstIndex(where: { $0.id == requestId }) {
                    var accepted = pendingRequests.remove(at: idx)
                    accepted.status = .accepted
                    self.activeServiceRequests.append(accepted)
                }
            }
            self.successMessage = "Job accepted! Customer has been notified."
        } catch {
            self.errorMessage = "Failed to accept job: \(error.localizedDescription)"
            print("[BengkelVM] acceptJob error: \(error)")
        }
        isLoading = false
    }
    
    /// Finishes the specified active job by marking it as completed.
    func finishJob(requestId: String) async {
        isLoading = true
        errorMessage = nil
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let update = ServiceRequestStatusUpdate(
            status: ServiceRequestStatus.completed.rawValue,
            mechanicNotes: nil,
            updatedAt: isoFormatter.string(from: Date())
        )
        
        do {
            try await supabase.from("service_requests")
                .update(update)
                .eq("id", value: requestId)
                .execute()
            
            withAnimation {
                let price = self.activeServiceRequests.first(where: { $0.id == requestId })?.estimatedPrice ?? 0
                self.todaysEarnings += price
                self.activeServiceRequests.removeAll { $0.id == requestId }
            }
            self.successMessage = "Job completed! Earnings updated."
        } catch {
            self.errorMessage = "Failed to complete job: \(error.localizedDescription)"
            print("[BengkelVM] finishJob error: \(error)")
        }
        isLoading = false
    }
    
    /// Assigns a mechanic to a specific service request.
    func dispatchMechanic(requestId: String, mechanicId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let updatePayload = ServiceRequestStatusUpdate(
            status: ServiceRequestStatus.accepted.rawValue,
            mechanicNotes: nil,
            mechanicId: mechanicId,
            updatedAt: isoFormatter.string(from: Date())
        )
        
        do {
            try await supabase.from("service_requests")
                .update(updatePayload)
                .eq("id", value: requestId)
                .execute()
            
            self.successMessage = "Mechanic successfully dispatched!"
            isLoading = false
            return true
        } catch {
            self.errorMessage = "Dispatch failed: \(error.localizedDescription)"
            print("[BengkelVM] dispatchMechanic error: \(error)")
            isLoading = false
            return false
        }
    }
    
    struct BengkelUpdateRequest: Encodable {
        let name: String
        let address: String
        let latitude: Double
        let longitude: Double
    }
    
    func registerBengkel(name: String, address: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "You must be logged in to register a Bengkel."
            isLoading = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        
        var lat: Double = 0.0
        var lon: Double = 0.0
        
        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = address
            
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            if let coordinate = response.mapItems.first?.location.coordinate {
                lat = coordinate.latitude
                lon = coordinate.longitude
            } else {
                self.errorMessage = "Could not find coordinates for this address. Please be more specific."
                isLoading = false
                return false
            }
        } catch {
            self.errorMessage = "Address lookup failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
        
        let newBengkel = Bengkel(
            id: nil,
            providerUid: uid,
            name: name,
            address: address,
            latitude: lat,
            longitude: lon,
            status: "Pending",
            offeredServices: [],
            averageRating: 0.0,
            totalReviews: 0,
            createdAt: nil
        )
        
        do {
            try await supabase.from("bengkels").insert(newBengkel).execute()
            self.successMessage = "Bengkel submitted for review! You will be notified once approved."
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func fetchMyBengkel(uid: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedBengkel: Bengkel = try await supabase.from("bengkels")
                .select()
                .eq("provider_uid", value: uid)
                .single()
                .execute()
                .value
            
            self.myBengkel = fetchedBengkel
        } catch {
            self.errorMessage = "Failed to load Bengkel: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func updateBengkel(bengkelId: String, name: String, address: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = address
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            guard let coordinate = response.mapItems.first?.location.coordinate else {
                self.errorMessage = "Could not find coordinates for this address."
                isLoading = false
                return false
            }
            
            let updateData = BengkelUpdateRequest(
                name: name,
                address: address,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            
            try await supabase.from("bengkels").update(updateData).eq("id", value: bengkelId).execute()
            
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func deleteBengkel(bengkelId: String, password: String, email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
            
            try await supabase.from("bengkels").delete().eq("id", value: bengkelId).execute()
            
            self.myBengkel = nil
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func addService(bengkelId: String, serviceName: String, description: String, isActive: Bool) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            guard var currentBengkel = self.myBengkel else {
                self.errorMessage = "Bengkel data not found."
                isLoading = false
                return false
            }
            
            let newService = BengkelService(
                serviceName: serviceName,
                description: description,
                isActive: isActive
            )
            
            if currentBengkel.offeredServices != nil {
                currentBengkel.offeredServices?.append(newService)
            } else {
                currentBengkel.offeredServices = [newService]
            }
            
            try await supabase.from("bengkels").update(currentBengkel).eq("id", value: bengkelId).execute()
            
            self.myBengkel = currentBengkel
            
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func updateService(bengkelId: String, serviceId: String, serviceName: String, description: String, isActive: Bool) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            guard var currentBengkel = self.myBengkel else { return false }
            
            if let index = currentBengkel.offeredServices?.firstIndex(where: { $0.id == serviceId }) {
                currentBengkel.offeredServices?[index].serviceName = serviceName
                currentBengkel.offeredServices?[index].description = description
                currentBengkel.offeredServices?[index].isActive = isActive
                
                try await supabase.from("bengkels").update(currentBengkel).eq("id", value: bengkelId).execute()
                
                self.myBengkel = currentBengkel
            }
            
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func deleteService(bengkelId: String, serviceId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            guard var currentBengkel = self.myBengkel else { return false }
            
            currentBengkel.offeredServices?.removeAll { $0.id == serviceId }
            
            try await supabase.from("bengkels").update(currentBengkel).eq("id", value: bengkelId).execute()
            
            self.myBengkel = currentBengkel
            
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Mechanic Management (Live — from users table)
    
    @Published var teamMembers: [User] = []
    @Published var availableMechanics: [Mechanic] = [] // Kept for backwards compatibility if needed elsewhere
    
    /// Fetches mechanics linked to this bengkel from the users table using the mechanic_uids array.
    func fetchTeamProfiles() async {
        do {
            guard let uids = self.myBengkel?.mechanicUids, !uids.isEmpty else {
                await MainActor.run {
                    self.teamMembers = []
                    self.availableMechanics = []
                }
                return
            }
            
            let users: [User] = try await supabase.from("users")
                .select()
                .in("id", values: uids)
                .execute()
                .value
            
            await MainActor.run {
                self.teamMembers = users
                self.availableMechanics = users.map { 
                    Mechanic(id: $0.id, name: $0.name, email: $0.email, status: .available, linkedBengkelId: self.myBengkel?.id ?? "") 
                }
            }
        } catch {
            print("[BengkelVM] fetchTeamProfiles error: \(error)")
        }
    }
    
    /// Legacy fetch Mechanics (redirects to fetchTeamProfiles)
    func fetchMechanics(bengkelId: String) async {
        await fetchTeamProfiles()
    }
    
    struct BengkelMechanicsUpdate: Encodable {
        let mechanic_uids: [String]
    }
    
    // MARK: - Mechanic Invitation (Email-Based Flow)
    
    /// Sent invitations tracked for the provider dashboard display.
    @Published var sentInvitations: [MechanicInvitation] = []
    
    /// RPC response shape for `get_user_by_email`.
    private struct RPCUserLookup: Decodable {
        let user_id: String
        let user_name: String
    }
    
    /// Invites a mechanic by email using the secure RPC endpoint.
    ///
    /// Flow:
    /// 1. Call `get_user_by_email` RPC → resolve email to user_id
    /// 2. Check for duplicate (already a mechanic or already invited)
    /// 3. INSERT into `mechanic_invitations` with status `pending`
    func inviteMechanic(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        guard let currentBengkel = self.myBengkel, let bengkelId = currentBengkel.id else {
            self.errorMessage = "Bengkel data not found."
            isLoading = false
            return false
        }
        
        // Step A: Resolve email → user_id via RPC
        let resolvedUserId: String
        let resolvedUserName: String
        
        do {
            let results: [RPCUserLookup] = try await supabase
                .rpc("get_user_by_email", params: ["search_email": email])
                .execute()
                .value
            
            guard let found = results.first else {
                self.errorMessage = "User must create an MbengkelIn account first."
                isLoading = false
                return false
            }
            
            resolvedUserId = found.user_id
            resolvedUserName = found.user_name
        } catch {
            self.errorMessage = "Failed to look up user: \(error.localizedDescription)"
            print("[BengkelVM] RPC get_user_by_email error: \(error)")
            isLoading = false
            return false
        }
        
        // Step B: Check if already a mechanic on this bengkel
        let existingUids = currentBengkel.mechanicUids ?? []
        if existingUids.contains(resolvedUserId) {
            self.errorMessage = "\(resolvedUserName) is already a mechanic at your bengkel."
            isLoading = false
            return false
        }
        
        // Step B2: Check if there's already a pending invitation
        do {
            let existingInvites: [MechanicInvitation] = try await supabase
                .from("mechanic_invitations")
                .select()
                .eq("bengkel_id", value: bengkelId)
                .eq("mechanic_id", value: resolvedUserId)
                .eq("status", value: InvitationStatus.pending.rawValue)
                .execute()
                .value
            
            if !existingInvites.isEmpty {
                self.errorMessage = "An invitation is already pending for \(resolvedUserName)."
                isLoading = false
                return false
            }
        } catch {
            print("[BengkelVM] Duplicate invite check error: \(error)")
            // Non-fatal — proceed with the insert and let DB constraints handle it
        }
        
        // Step C: Insert invitation
        do {
            let payload = MechanicInvitationInsert(
                bengkelId: bengkelId,
                mechanicId: resolvedUserId,
                status: InvitationStatus.pending.rawValue
            )
            
            try await supabase.from("mechanic_invitations")
                .insert(payload)
                .execute()
            
            self.successMessage = "Invitation sent to \(resolvedUserName)!"
            
            // Refresh sent invitations
            await fetchSentInvitations(bengkelId: bengkelId)
            
            isLoading = false
            return true
        } catch {
            self.errorMessage = "Failed to send invitation: \(error.localizedDescription)"
            print("[BengkelVM] insert mechanic_invitations error: \(error)")
            isLoading = false
            return false
        }
    }
    
    /// Fetches all invitations sent by this bengkel (for provider dashboard display).
    func fetchSentInvitations(bengkelId: String) async {
        do {
            let invites: [MechanicInvitation] = try await supabase
                .from("mechanic_invitations")
                .select()
                .eq("bengkel_id", value: bengkelId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.sentInvitations = invites
        } catch {
            print("[BengkelVM] fetchSentInvitations error: \(error)")
        }
    }
    
    /// Assigns a mechanic to a service request by updating the request.
    /// In production, this could set a `mechanic_id` column on service_requests.
    func assignMechanic(to orderId: String, mechanicId: String) {
        print("[BengkelVM] assignMechanic called — order: \(orderId), mechanic: \(mechanicId)")
        
        if let index = availableMechanics.firstIndex(where: { $0.id == mechanicId }) {
            withAnimation(.easeInOut) {
                availableMechanics[index].status = .busy
            }
            successMessage = "Mechanic assigned successfully!"
        } else {
            errorMessage = "Mechanic not found."
        }
    }
    
    // MARK: - Voucher / Promo Management
    
    @Published var providerVouchers: [Voucher] = []
    
    func fetchProviderPromos() async {
        guard let session = try? await supabase.auth.session else { return }
        let uid = session.user.id.uuidString.lowercased()
        
        do {
            let fetched: [Voucher] = try await supabase.from("vouchers")
                .select()
                .eq("provider_uid", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.providerVouchers = fetched
        } catch {
            print("[BengkelVM] fetchProviderPromos error: \(error)")
        }
    }
    
    struct VoucherInsert: Encodable {
        let code: String
        let title: String
        let discountAmount: Double
        let validUntil: String
        let providerUid: String

        enum CodingKeys: String, CodingKey {
            case code, title
            case discountAmount = "discount_amount"
            case validUntil = "valid_until"
            case providerUid = "provider_uid"
        }
    }
    
    func createPromo(code: String, title: String, discount: Double, validUntil: Date) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "Not logged in."
            isLoading = false
            return false
        }
        let uid = session.user.id.uuidString.lowercased()
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let dateStr = isoFormatter.string(from: validUntil)
        
        let payload = VoucherInsert(
            code: code,
            title: title,
            discountAmount: discount,
            validUntil: dateStr,
            providerUid: uid
        )
        
        do {
            try await supabase.from("vouchers").insert(payload).execute()
            self.successMessage = "Promo created successfully!"
            await fetchProviderPromos()
            isLoading = false
            return true
        } catch {
            self.errorMessage = "Failed to create promo: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
}
