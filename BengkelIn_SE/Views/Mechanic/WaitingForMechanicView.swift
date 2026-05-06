//
//  WaitingForMechanicView.swift
//  BengkelIn_SE
//
//  Realtime wait screen. Observes mechanicVM.activeRequest to react to status changes.
//

import SwiftUI

struct WaitingForMechanicView: View {
    @ObservedObject var mechanicVM: MechanicViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isPulsing = false
    
    var requestStatus: ServiceRequestStatus {
        mechanicVM.activeRequest?.status ?? .pending
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // MARK: - Animated Status Icon
            ZStack {
                if requestStatus == .pending {
                    // Pulsing Radar Effect
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(isPulsing ? 1.5 : 0.8)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                    
                    Circle()
                        .stroke(Color.blue.opacity(0.5), lineWidth: 4)
                        .frame(width: 100, height: 100)
                        .scaleEffect(isPulsing ? 1.2 : 0.6)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).delay(0.2).repeatForever(autoreverses: false), value: isPulsing)
                    
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                } else if requestStatus == .accepted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .transition(.scale)
                } else if requestStatus == .cancelled {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                        .transition(.scale)
                } else {
                    // In Progress or Completed
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                }
            }
            .frame(height: 180)
            .onAppear {
                isPulsing = true
            }
            
            // MARK: - Status Text
            VStack(spacing: 12) {
                Text(statusTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(statusDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // MARK: - Action Buttons
            if requestStatus == .pending {
                Button(role: .destructive, action: {
                    cancelRequest()
                }) {
                    Text("Cancel Request")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            } else {
                Button(action: {
                    dismiss()
                }) {
                    Text("Go to Dashboard")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true) // Prevent accidental back swipe while waiting
        .animation(.easeInOut, value: requestStatus)
    }
    
    // MARK: - Computed Status Strings
    
    private var statusTitle: String {
        switch requestStatus {
        case .pending: return "Finding a Mechanic..."
        case .accepted: return "Mechanic is on the way!"
        case .inProgress: return "Work in Progress"
        case .completed: return "Service Completed"
        case .cancelled: return "Request Cancelled"
        }
    }
    
    private var statusDescription: String {
        switch requestStatus {
        case .pending:
            return "We have sent your request to the bengkel. Please wait while they confirm availability."
        case .accepted:
            return "The bengkel has accepted your request. The mechanic will arrive shortly."
        case .inProgress:
            return "The mechanic is currently working on your vehicle."
        case .completed:
            return "The job is done! You can view the details in your dashboard."
        case .cancelled:
            return "This service request has been cancelled."
        }
    }
    
    // MARK: - Actions
    
    private func cancelRequest() {
        guard let id = mechanicVM.activeRequest?.id else { return }
        Task {
            let success = await mechanicVM.cancelServiceRequest(requestId: id)
            if success {
                dismiss() // Pop back
            }
        }
    }
}
