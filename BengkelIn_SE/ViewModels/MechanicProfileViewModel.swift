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
    
    init() {}
    
    func fetchMyBengkel() async {
        guard self.myBengkel == nil else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result: Bengkel = try await supabase
                .rpc("get_my_bengkel")
                .single()
                .execute()
                .value
            
            self.myBengkel = result
            print("✅ [MechanicProfileVM] Successfully loaded Bengkel: \(result.name)")
            
        } catch {
            print("⚠️ [MechanicProfileVM] User is not linked to a Bengkel or fetch failed: \(error)")
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
            // 1. Verify password to confirm intent
            _ = try await supabase.auth.signIn(email: email, password: password)
            
            // 2. Submit payload
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
