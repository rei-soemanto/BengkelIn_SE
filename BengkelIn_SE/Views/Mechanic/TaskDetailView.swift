//
//  TaskDetailView.swift
//  BengkelIn_SE
//
//  Created for Mechanic feature on 05/05/26.
//

import SwiftUI

struct TaskDetailView: View {
    let task: MechanicTask
    @ObservedObject var mechanicVM: MechanicViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false
    @State private var isUploading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Emergency Badge
                if task.isEmergency {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                        Text("Emergency Request")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                
                // MARK: - Order Info
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Order ID")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(task.orderId)
                            .font(.subheadline)
                            .fontDesign(.monospaced)
                    }
                    
                    Divider()
                    
                    detailRow(icon: "wrench.and.screwdriver.fill", title: "Service", value: task.serviceType)
                    detailRow(icon: "person.fill", title: "Customer", value: task.customerName)
                    detailRow(icon: "car.fill", title: "Vehicle", value: task.vehicleInfo)
                    detailRow(icon: "location.fill", title: "Location", value: task.location)
                    detailRow(icon: "arrow.triangle.swap", title: "Distance", value: String(format: "%.1f km", task.distanceKm))
                    detailRow(icon: "banknote.fill", title: "Est. Price", value: task.estimatedPrice.toRupiah())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // MARK: - Photo Upload Placeholder
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Upload proof of completed work")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Photo upload will be available\nwhen backend is integrated.")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .foregroundColor(.gray.opacity(0.3))
                )
                
                // MARK: - Complete Button
                Button {
                    showConfirmation = true
                } label: {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .tint(.white)
                        }
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Job & Upload Photo")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(isUploading)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Complete This Job?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Complete", role: .none) {
                completeTask()
            }
        } message: {
            Text("This will mark the job as completed and notify the customer. This action cannot be undone.")
        }
    }
    
    // MARK: - Helpers
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
            }
            Spacer()
        }
    }
    
    private func completeTask() {
        isUploading = true
        mechanicVM.completeTask(taskId: task.id) {
            isUploading = false
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(
            task: MechanicTask(
                id: "preview-1",
                orderId: "ORD-PREVIEW-001",
                customerName: "Ahmad Yusuf",
                vehicleInfo: "Honda Brio 2022 — B 1234 ABC",
                serviceType: "Flat Tire Repair",
                location: "Jl. Sudirman No. 45, Jakarta",
                isEmergency: true,
                distanceKm: 2.4,
                estimatedPrice: 150_000
            ),
            mechanicVM: MechanicViewModel()
        )
    }
}
