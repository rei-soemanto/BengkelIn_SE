//
//  MechanicViewModel.swift
//  BengkelIn_SE
//
//  Created for Mechanic feature on 05/05/26.
//

import SwiftUI
import Combine

/// Represents an assigned task for a mechanic.
/// Uses mock data only — no backend integration.
struct MechanicTask: Identifiable {
    let id: String
    let orderId: String
    let customerName: String
    let vehicleInfo: String
    let serviceType: String
    let location: String
    let isEmergency: Bool
    let distanceKm: Double
    let estimatedPrice: Double
    var isCompleted: Bool = false
}

@MainActor
class MechanicViewModel: ObservableObject {
    @Published var assignedTasks: [MechanicTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    init() {
        // MARK: - Mock Data (replace with Supabase calls later)
        assignedTasks = [
            MechanicTask(
                id: UUID().uuidString,
                orderId: "ORD-20260505-001",
                customerName: "Ahmad Yusuf",
                vehicleInfo: "Honda Brio 2022 — B 1234 ABC",
                serviceType: "Flat Tire Repair",
                location: "Jl. Sudirman No. 45, Jakarta",
                isEmergency: true,
                distanceKm: 2.4,
                estimatedPrice: 150_000
            ),
            MechanicTask(
                id: UUID().uuidString,
                orderId: "ORD-20260505-002",
                customerName: "Siti Rahma",
                vehicleInfo: "Toyota Avanza 2020 — D 5678 DEF",
                serviceType: "Battery Jump Start",
                location: "Jl. Gatot Subroto No. 12, Jakarta",
                isEmergency: true,
                distanceKm: 4.1,
                estimatedPrice: 200_000
            )
        ]
    }
    
    /// Stub: Simulates uploading proof-of-work and completing a task.
    /// In production, this will upload a photo to Supabase Storage and update the order status.
    func uploadProofOfWork(for taskId: String) {
        print("[MechanicVM] uploadProofOfWork called for task: \(taskId)")
        print("[MechanicVM] Simulating photo upload... ✅ Success (mock)")
        
        withAnimation(.easeInOut) {
            assignedTasks.removeAll { $0.id == taskId }
        }
        
        successMessage = "Job completed successfully! Proof uploaded."
        print("[MechanicVM] Task \(taskId) removed from assigned list.")
    }
}
