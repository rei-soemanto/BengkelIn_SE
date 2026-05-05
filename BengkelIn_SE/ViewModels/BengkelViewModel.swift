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

@MainActor
class BengkelViewModel: ObservableObject {
    @Published var myBengkel: Bengkel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Provider Job State (Mock Data — will be replaced by backend)
    @Published var hasActiveJob: Bool = false
    @Published var todaysEarnings: Double = 0.0
    @Published var pendingRequestsCount: Int = 1
    @Published var incomingJobTitle: String = "Flat Tire - Honda Brio"
    @Published var incomingJobDistance: Double = 2.4
    @Published var activeJobTitle: String = "Fixing Flat Tire - Honda Brio"
    @Published var activeJobStatus: String = "Job is currently in progress..."
    
    /// Accepts an incoming job offer. Transitions the dashboard to active job state.
    func acceptJob() {
        withAnimation {
            hasActiveJob = true
        }
    }
    
    /// Finishes the current active job. Awards earnings and decrements the pending count.
    func finishJob() {
        withAnimation {
            hasActiveJob = false
            if pendingRequestsCount > 0 {
                pendingRequestsCount -= 1
            }
            todaysEarnings += 150_000
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
            
            currentBengkel.offeredServices.append(newService)
            
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
            
            if let index = currentBengkel.offeredServices.firstIndex(where: { $0.id == serviceId }) {
                currentBengkel.offeredServices[index].serviceName = serviceName
                currentBengkel.offeredServices[index].description = description
                currentBengkel.offeredServices[index].isActive = isActive
                
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
            
            currentBengkel.offeredServices.removeAll { $0.id == serviceId }
            
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
    
    // MARK: - Mechanic Management (Mock Data — No Backend)
    
    @Published var availableMechanics: [Mechanic] = [
        Mechanic(
            id: "mech-001",
            name: "Budi Santoso",
            status: .available,
            linkedBengkelId: nil
        ),
        Mechanic(
            id: "mech-002",
            name: "Dimas Prasetyo",
            status: .available,
            linkedBengkelId: nil
        ),
        Mechanic(
            id: "mech-003",
            name: "Eko Wijaya",
            status: .busy,
            linkedBengkelId: nil
        )
    ]
    
    /// Stub: Assigns a mechanic to an order by setting their status to busy.
    /// In production, this will call the Supabase backend.
    func assignMechanic(to orderId: String, mechanicId: String) {
        print("[BengkelVM] assignMechanic called — order: \(orderId), mechanic: \(mechanicId)")
        
        if let index = availableMechanics.firstIndex(where: { $0.id == mechanicId }) {
            withAnimation(.easeInOut) {
                availableMechanics[index].status = .busy
            }
            print("[BengkelVM] Mechanic \(mechanicId) is now busy (mock).")
            successMessage = "Mechanic assigned successfully!"
        } else {
            errorMessage = "Mechanic not found."
        }
    }
}
