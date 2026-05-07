//
//  MechanicDashboardView.swift
//  BengkelIn_SE
//
//  Created for Mechanic feature on 05/05/26.
//  Phase 1 Backend Migration — Live Supabase Integration on 07/05/26.
//

import SwiftUI
import Combine

struct MechanicDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var mechanicVM = MechanicViewModel()
    @StateObject private var invitationVM = InvitationViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mechanic Dashboard")
                                .font(.title3)
                                .foregroundColor(.gray)
                            Text("My Tasks")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                    
                    // MARK: - Invitations Banner
                    if !invitationVM.pendingInvitations.isEmpty {
                        NavigationLink(destination: InvitationsView(authViewModel: authViewModel)) {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.badge.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("You have \(invitationVM.pendingInvitations.count) pending invitation\(invitationVM.pendingInvitations.count > 1 ? "s" : "")")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("Tap to view and respond")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - Stats Row
                    HStack(spacing: 12) {
                        StatBox(
                            title: "Active Tasks",
                            value: "\(mechanicVM.assignedTasks.filter { $0.status != .completed && $0.status != .cancelled }.count)",
                            icon: "wrench.and.screwdriver.fill",
                            color: .blue
                        )
                        
                        StatBox(
                            title: "Emergency",
                            value: "\(mechanicVM.assignedTasks.filter(\.isEmergency).count)",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange
                        )
                    }
                    
                    // MARK: - Error Banner
                    if let error = mechanicVM.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // MARK: - Success Banner
                    if let success = mechanicVM.successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(success)
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // MARK: - Loading
                    if mechanicVM.isLoading {
                        ProgressView("Loading tasks...")
                            .padding()
                    }
                    
                    // MARK: - Assigned Tasks
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Assigned Tasks")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        let activeTasks = mechanicVM.assignedTasks.filter {
                            $0.status != .completed && $0.status != .cancelled
                        }
                        
                        if activeTasks.isEmpty && !mechanicVM.isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No tasks assigned")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("You're all caught up!")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            ForEach(activeTasks) { request in
                                NavigationLink(destination: TaskDetailView(request: request, mechanicVM: mechanicVM)) {
                                    taskCard(request)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                }
                .padding()
            }
            .animation(.easeInOut, value: mechanicVM.assignedTasks.count)
            .task {
                await mechanicVM.fetchAssignedTasks()
                await invitationVM.fetchPendingInvitations()
            }
            .refreshable {
                await mechanicVM.fetchAssignedTasks()
                await invitationVM.fetchPendingInvitations()
            }

        }
    }
    
    // MARK: - Task Card
    private func taskCard(_ request: ServiceRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if request.isEmergency {
                    Label("EMERGENCY", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(6)
                }
                
                statusBadge(request.status)
                
                Spacer()
                
                if let id = request.id {
                    Text(String(id.prefix(8)).uppercased())
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fontDesign(.monospaced)
                }
            }
            
            Text(request.serviceType)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                if let location = request.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let price = request.estimatedPrice {
                    Label(price.toRupiah(), systemImage: "banknote.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(request.isEmergency ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
    
    // MARK: - Status Badge
    private func statusBadge(_ status: ServiceRequestStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .pending:    return ("Pending", .orange)
            case .accepted:   return ("Accepted", .blue)
            case .inProgress: return ("In Progress", .purple)
            case .completed:  return ("Completed", .green)
            case .cancelled:  return ("Cancelled", .gray)
            }
        }()
        
        return Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

#Preview("Light Mode") {
    MechanicDashboardView(authViewModel: AuthViewModel())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    MechanicDashboardView(authViewModel: AuthViewModel())
        .preferredColorScheme(.dark)
}
