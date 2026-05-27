//
//  TaskDetailView.swift
//  BengkelIn_SE
//
//  Created for Mechanic feature on 05/05/26.
//  Phase 1 Backend Migration — Live Supabase Integration on 07/05/26.
//

import SwiftUI

struct TaskDetailView: View {
    let request: ServiceRequest
    @ObservedObject var mechanicVM: MechanicViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false
    @State private var isProcessing = false
    @State private var mechanicNotes = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Emergency Badge
                if request.isEmergency {
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
                
                // MARK: - Status Banner
                statusBanner
                
                // MARK: - Request Info
                VStack(alignment: .leading, spacing: 16) {
                    if let id = request.id {
                        HStack {
                            Text("Request ID")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(id.prefix(12)).uppercased())
                                .font(.subheadline)
                                .fontDesign(.monospaced)
                        }
                        
                        Divider()
                    }
                    
                    detailRow(icon: "wrench.and.screwdriver.fill", title: "Service", value: request.serviceType)
                    
                    if let location = request.location {
                        detailRow(icon: "location.fill", title: "Location", value: location)
                    }
                    
                    if let price = request.estimatedPrice {
                        detailRow(icon: "banknote.fill", title: "Est. Price", value: price.toRupiah())
                    }
                    
                    if let desc = request.description, !desc.isEmpty {
                        detailRow(icon: "text.alignleft", title: "Notes", value: desc)
                    }
                    
                    if let notes = request.mechanicNotes, !notes.isEmpty {
                        detailRow(icon: "note.text", title: "Mechanic Notes", value: notes)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // MARK: - Mechanic Notes Input (for completion)
                if request.status == .inProgress {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Completion Notes")
                            .font(.headline)
                        
                        TextField("Add notes about the work done...", text: $mechanicNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                }
                
                // MARK: - Photo Upload Placeholder
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Upload proof of completed work")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Photo upload will be available\nin a future update (Supabase Storage).")
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
                
                // MARK: - Action Buttons
                actionButtons
                
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
    
    // MARK: - Status Banner
    private var statusBanner: some View {
        let (icon, text, color): (String, String, Color) = {
            switch request.status {
            case .pending:    return ("clock.fill", "Awaiting Confirmation", .orange)
            case .accepted:   return ("checkmark.circle.fill", "Accepted — Ready to Start", .blue)
            case .inProgress: return ("wrench.fill", "Work in Progress", .purple)
            case .completed:  return ("checkmark.seal.fill", "Completed", .green)
            case .cancelled:  return ("xmark.circle.fill", "Cancelled", .gray)
            }
        }()
        
        return HStack {
            Image(systemName: icon)
            Text(text)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    @ViewBuilder
    private var actionButtons: some View {
        if isProcessing {
            ProgressView("Processing...")
                .padding()
        } else {
            switch request.status {
            case .pending:
                // Provider can accept
                Button {
                    acceptRequest()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept Request")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
            case .accepted:
                // Mechanic can start work
                Button {
                    startWork()
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Start Work")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
                }
                
            case .inProgress:
                // Mechanic can complete
                Button {
                    showConfirmation = true
                } label: {
                    HStack {
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
                
            case .completed, .cancelled:
                EmptyView()
            }
            
            // Cancel option for non-terminal states
            if request.status == .pending || request.status == .accepted {
                Button(role: .destructive) {
                    cancelRequest()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel Request")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
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
    
    private func acceptRequest() {
        guard let requestId = request.id else { return }
        isProcessing = true
        Task {
            let success = await mechanicVM.acceptServiceRequest(requestId: requestId)
            isProcessing = false
            if success {
                dismiss()
            }
        }
    }
    
    private func startWork() {
        guard let requestId = request.id else { return }
        isProcessing = true
        Task {
            let success = await mechanicVM.startWork(requestId: requestId)
            isProcessing = false
            if success {
                dismiss()
            }
        }
    }
    
    private func completeTask() {
        guard let requestId = request.id else { return }
        isProcessing = true
        Task {
            let notes = mechanicNotes.isEmpty ? nil : mechanicNotes
            let success = await mechanicVM.completeServiceRequest(requestId: requestId, notes: notes)
            isProcessing = false
            if success {
                dismiss()
            }
        }
    }
    
    private func cancelRequest() {
        guard let requestId = request.id else { return }
        isProcessing = true
        Task {
            let success = await mechanicVM.cancelServiceRequest(requestId: requestId)
            isProcessing = false
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(
            request: ServiceRequest(
                id: "preview-001",
                customerId: "user-001",
                vehicleId: "vehicle-001",
                bengkelId: "bengkel-001",
                serviceType: "Flat Tire Repair",
                description: "Front left tire is completely flat",
                status: .inProgress,
                isEmergency: true,
                location: "Jl. Sudirman No. 45, Jakarta",
                latitude: -6.2088,
                longitude: 106.8456,
                estimatedPrice: 150_000,
                mechanicNotes: nil,
                createdAt: Date(),
                updatedAt: nil
            ),
            mechanicVM: MechanicViewModel()
        )
    }
}
