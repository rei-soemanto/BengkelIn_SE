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
    /// The currently active (accepted/in_progress) request, if any.
    @Published var activeServiceRequest: ServiceRequest?
    /// Today's earnings (sum of completed request estimated prices).
    @Published var todaysEarnings: Double = 0.0
    
    var pendingRequestsCount: Int { pendingRequests.count }
    var hasActiveJob: Bool { activeServiceRequest != nil }
    
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
            self.activeServiceRequest = requests.first(where: {
                $0.status == .accepted || $0.status == .inProgress
            })
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
                    self.activeServiceRequest = accepted
                }
            }
            self.successMessage = "Job accepted! Customer has been notified."
        } catch {
            self.errorMessage = "Failed to accept job: \(error.localizedDescription)"
            print("[BengkelVM] acceptJob error: \(error)")
        }
        isLoading = false
    }
    
    /// Finishes the current active job by marking it as completed.
    func finishJob() async {
        guard let activeId = activeServiceRequest?.id else { return }
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
                .eq("id", value: activeId)
                .execute()
            
            withAnimation {
                let price = activeServiceRequest?.estimatedPrice ?? 0
                self.todaysEarnings += price
                self.activeServiceRequest = nil
            }
            self.successMessage = "Job completed! Earnings updated."
        } catch {
            self.errorMessage = "Failed to complete job: \(error.localizedDescription)"
            print("[BengkelVM] finishJob error: \(error)")
        }
        isLoading = false
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
    
    @Published var availableMechanics: [Mechanic] = []
    
    /// Fetches mechanics linked to this bengkel from the users table.
    /// Mechanics are users with `is_mechanic = true`.
    func fetchMechanics(bengkelId: String) async {
        do {
            guard let uids = self.myBengkel?.mechanicUids, !uids.isEmpty else {
                self.availableMechanics = []
                return
            }
            
            let users: [User] = try await supabase.from("users")
                .select("id, name, email")
                .in("id", values: uids)
                .execute()
                .value
            
            self.availableMechanics = users.map { 
                Mechanic(id: $0.id, name: $0.name, email: $0.email, status: .available, linkedBengkelId: bengkelId) 
            }
        } catch {
            print("[BengkelVM] fetchMechanics error: \(error)")
        }
    }
    
    struct BengkelMechanicsUpdate: Encodable {
        let mechanic_uids: [String]
    }
    
    /// Adds a mechanic to the bengkel by User ID
    func addMechanic(userId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Verify user exists
            let _: User = try await supabase.from("users")
                .select("id, name")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            guard var currentBengkel = self.myBengkel, let bengkelId = currentBengkel.id else { 
                isLoading = false
                return false 
            }
            
            var uids = currentBengkel.mechanicUids ?? []
            if uids.contains(userId) {
                self.errorMessage = "Mechanic is already added."
                isLoading = false
                return false
            }
            
            uids.append(userId)
            
            // 2. Update DB
            let updatePayload = BengkelMechanicsUpdate(mechanic_uids: uids)
            try await supabase.from("bengkels")
                .update(updatePayload)
                .eq("id", value: bengkelId)
                .execute()
            
            // 3. Update Local State
            currentBengkel.mechanicUids = uids
            self.myBengkel = currentBengkel
            
            // 4. Refresh Mechanics List
            await fetchMechanics(bengkelId: bengkelId)
            
            self.successMessage = "Mechanic added successfully!"
            isLoading = false
            return true
            
        } catch {
            self.errorMessage = "Failed to add mechanic: Please ensure the User ID is correct."
            isLoading = false
            return false
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
}
