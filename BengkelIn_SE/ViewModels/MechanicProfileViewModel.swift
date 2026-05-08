//
//  MechanicProfileViewModel.swift
//  BengkelIn
//

import SwiftUI
import Supabase
import Combine

@MainActor
class MechanicProfileViewModel: ObservableObject {
    @Published var myBengkel: Bengkel?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // STRICT RULE: Empty init to prevent recursion during initialization
    init() {}
    
    func fetchMyBengkel() async {
        // IDEMPOTENCY GUARD: Prevents infinite loop if data exists
        guard self.myBengkel == nil else { return }
        
        isLoading = true
        errorMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "Authentication error. Please log in again."
            self.isLoading = false
            return
        }
        
        let mechanicId = session.user.id.uuidString.lowercased()
        
        do {
            let results: [Bengkel] = try await supabase.from("bengkels")
                .select()
                .contains("mechanic_uids", value: [mechanicId])
                .execute()
                .value
            
            self.myBengkel = results.first
        } catch {
            self.errorMessage = "Failed to fetch linked bengkel: \(error.localizedDescription)"
            print("[MechanicProfileVM] fetch error: \(error)")
        }
        isLoading = false
    }
    
    func submitResignation(password: String) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        
        guard let session = try? await supabase.auth.session else {
            self.errorMessage = "Authentication error. Please log in again."
            self.isSubmitting = false
            return false
        }
        
        let mechanicId = session.user.id.uuidString.lowercased()
        let email = session.user.email ?? ""
        
        guard let bengkelId = myBengkel?.id else {
            self.errorMessage = "You are not currently linked to a Bengkel."
            isSubmitting = false
            return false
        }
        
        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
            
            let payload = MechanicResignationInsert(
                bengkelId: bengkelId,
                mechanicId: mechanicId,
                status: "pending"
            )
            
            try await supabase.from("mechanic_resignations")
                .insert(payload)
                .execute()
            
            self.successMessage = "Resignation request sent to owner."
            isSubmitting = false
            return true
        } catch {
            self.errorMessage = "Resignation failed: \(error.localizedDescription)"
            isSubmitting = false
            return false
        }
    }
}
