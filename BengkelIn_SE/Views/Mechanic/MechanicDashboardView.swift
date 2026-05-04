//
//  MechanicDashboardView.swift
//  BengkelIn_SE
//
//  Created for Mechanic feature on 05/05/26.
//

import SwiftUI

struct MechanicDashboardView: View {
    @StateObject private var mechanicVM = MechanicViewModel()
    
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
                    
                    // MARK: - Stats Row
                    HStack(spacing: 12) {
                        StatBox(
                            title: "Active Tasks",
                            value: "\(mechanicVM.assignedTasks.count)",
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
                    
                    // MARK: - Assigned Tasks
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Assigned Tasks")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if mechanicVM.assignedTasks.isEmpty {
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
                            ForEach(mechanicVM.assignedTasks) { task in
                                NavigationLink(destination: TaskDetailView(task: task, mechanicVM: mechanicVM)) {
                                    taskCard(task)
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
        }
    }
    
    // MARK: - Task Card
    private func taskCard(_ task: MechanicTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if task.isEmergency {
                    Label("EMERGENCY", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(6)
                }
                
                Spacer()
                
                Text(task.orderId)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fontDesign(.monospaced)
            }
            
            Text(task.serviceType)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                Label(task.customerName, systemImage: "person.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(String(format: "%.1f km", task.distanceKm), systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(task.vehicleInfo)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.gray)
                    .font(.caption)
                Text(task.location)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
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
                .stroke(task.isEmergency ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview("Light Mode") {
    MechanicDashboardView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    MechanicDashboardView()
        .preferredColorScheme(.dark)
}
