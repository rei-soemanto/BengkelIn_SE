//
//  BengkelDashboardView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//  Phase 1 Backend Migration — Live Supabase Integration on 07/05/26.
//

import SwiftUI

struct BengkelDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @StateObject private var bengkelViewModel = BengkelViewModel()
    @StateObject private var mechanicViewModel = MechanicViewModel()
    
    @State private var showingMechanicPicker = false
    @State private var selectedRequestId: String? = nil
    
    @State private var showingAddMechanic = false
    @State private var newMechanicId: String = ""
    
    var realShopRating: Double {
        bengkelViewModel.myBengkel?.averageRating ?? 0.0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider Dashboard")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text(bengkelViewModel.myBengkel?.name ?? "Manage Your Shop")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shop Rating")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if bengkelViewModel.isLoading && bengkelViewModel.myBengkel == nil {
                        ProgressView()
                    } else {
                        HStack(spacing: 12) {
                            Text(String(format: "%.1f", realShopRating))
                                .font(.title)
                                .fontWeight(.bold)
                            
                            StarRatingView(rating: realShopRating)
                            
                            Spacer()
                            
                            Text("(\(bengkelViewModel.myBengkel?.totalReviews ?? 0) Reviews)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Earnings")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "banknote.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text(bengkelViewModel.todaysEarnings.toRupiah())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // MARK: - My Mechanics
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("My Mechanics")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Text("Manage Staffing (Coming Soon)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }
                    
                    if bengkelViewModel.availableMechanics.isEmpty {
                        Text("No mechanics found.")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    } else {
                        ForEach(bengkelViewModel.availableMechanics) { mechanic in
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mechanic.name)
                                        .font(.headline)
                                    if let email = mechanic.email {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(mechanic.status.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(mechanic.status == .available ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                    .foregroundColor(mechanic.status == .available ? .green : .red)
                                    .cornerRadius(8)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(bengkelViewModel.hasActiveJob ? "Current Active Job" : "Incoming Requests")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if !bengkelViewModel.hasActiveJob && bengkelViewModel.pendingRequestsCount > 0 {
                            Text("\(bengkelViewModel.pendingRequestsCount) Pending")
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    if bengkelViewModel.hasActiveJob, let active = bengkelViewModel.activeServiceRequest {
                        VStack(spacing: 12) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                                .padding(.bottom, 4)
                            
                            Text(active.serviceType)
                                .font(.headline)
                            
                            Text("Status: \(active.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            if let location = active.location {
                                Label(location, systemImage: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button("Finish Job") {
                                Task {
                                    await bengkelViewModel.finishJob()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding(.top, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )
                        
                    } else {
                        if let firstPending = bengkelViewModel.pendingRequests.first {
                            VStack(spacing: 12) {
                                Image(systemName: firstPending.isEmergency ? "exclamationmark.triangle.fill" : "bell.badge.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(firstPending.isEmergency ? .red : .orange)
                                    .padding(.bottom, 4)
                                
                                Text(firstPending.serviceType)
                                    .font(.headline)
                                
                                if let location = firstPending.location {
                                    Label(location, systemImage: "mappin.and.ellipse")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                if firstPending.isEmergency {
                                    Text("EMERGENCY")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .cornerRadius(6)
                                }
                                
                                Button("Accept & Dispatch Mechanic") {
                                    if let requestId = firstPending.id {
                                        selectedRequestId = requestId
                                        showingMechanicPicker = true
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 12)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No incoming requests")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .task {
            if let uid = authViewModel.currentUser?.id {
                await bengkelViewModel.fetchMyBengkel(uid: uid)
                
                if let bengkelId = bengkelViewModel.myBengkel?.id {
                    await bengkelViewModel.fetchServiceRequests(bengkelId: bengkelId)
                    await bengkelViewModel.fetchTodaysEarnings(bengkelId: bengkelId)
                    await bengkelViewModel.fetchMechanics(bengkelId: bengkelId)
                }
            }
        }
        .sheet(isPresented: $showingAddMechanic) {
            NavigationStack {
                Form {
                    Section(header: Text("Mechanic Details")) {
                        TextField("Enter User ID", text: $newMechanicId)
                    }
                    Button("Add Mechanic") {
                        Task {
                            let success = await bengkelViewModel.addMechanic(userId: newMechanicId)
                            if success {
                                newMechanicId = ""
                                showingAddMechanic = false
                            }
                        }
                    }
                    .disabled(newMechanicId.isEmpty || bengkelViewModel.isLoading)
                    
                    if let error = bengkelViewModel.errorMessage {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }
                .navigationTitle("Add Mechanic")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") { showingAddMechanic = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingMechanicPicker) {
            NavigationStack {
                List(bengkelViewModel.availableMechanics) { mechanic in
                    Button(action: {
                        if let reqId = selectedRequestId {
                            Task {
                                let success = await mechanicViewModel.assignMechanic(requestId: reqId, mechanicId: mechanic.id)
                                if success {
                                    if let bengkelId = bengkelViewModel.myBengkel?.id {
                                        await bengkelViewModel.fetchServiceRequests(bengkelId: bengkelId)
                                    }
                                    showingMechanicPicker = false
                                }
                            }
                        }
                    }) {
                        HStack {
                            Text(mechanic.name)
                            Spacer()
                            if mechanic.status == .available {
                                Text("Dispatch").fontWeight(.bold).foregroundColor(.blue)
                            } else {
                                Text("Busy").foregroundColor(.gray)
                            }
                        }
                    }
                    .disabled(mechanic.status != .available)
                }
                .navigationTitle("Dispatch Mechanic")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") { showingMechanicPicker = false }
                    }
                }
                .overlay {
                    if mechanicViewModel.isLoading {
                        ProgressView()
                    } else if bengkelViewModel.availableMechanics.isEmpty {
                        Text("No mechanics available. Please add one first.")
                            .foregroundColor(.gray)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview ("Light Mode") {
    BengkelDashboardView(authViewModel: AuthViewModel())
        .preferredColorScheme(.light)
}

#Preview ("Dark Mode") {
    BengkelDashboardView(authViewModel: AuthViewModel())
        .preferredColorScheme(.dark)
}
