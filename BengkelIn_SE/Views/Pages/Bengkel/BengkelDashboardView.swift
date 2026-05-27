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
    @State private var newMechanicEmail: String = ""
    
    @State private var showingCreatePromo = false
    
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
                
                // MARK: - Global Error Banner
                if let error = bengkelViewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // MARK: - Global Success Banner
                if let success = bengkelViewModel.successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(success)
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
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
                        Button {
                            showingAddMechanic = true
                        } label: {
                            Label("Invite Mechanic", systemImage: "person.badge.plus")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    if bengkelViewModel.teamMembers.isEmpty {
                        Text("No mechanics found.")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    } else {
                        ForEach(bengkelViewModel.teamMembers) { member in
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name)
                                        .font(.headline)
                                    if let email = member.email {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("Available")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // MARK: - Pending Invitations
                    let pendingInvites = bengkelViewModel.sentInvitations.filter { $0.status == .pending }
                    if !pendingInvites.isEmpty {
                        Divider()
                        
                        Text("Pending Invitations")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        ForEach(pendingInvites) { invite in
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.badge.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mechanic ID: \(String(invite.mechanicId.prefix(8)))...")
                                        .font(.subheadline)
                                        .fontDesign(.monospaced)
                                    Text("Awaiting response")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                                
                                Text("Pending")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(6)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    
                    // MARK: - Resignation Requests
                    if !bengkelViewModel.pendingResignations.isEmpty {
                        Divider()
                        
                        Text("Resignation Requests")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        ForEach(bengkelViewModel.pendingResignations) { resignation in
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill.xmark")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resignation.users?.name ?? "Unknown Mechanic")
                                        .font(.headline)
                                    Text("Wants to resign")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Spacer()
                                
                                Button {
                                    Task {
                                        await bengkelViewModel.approveResignation(resignationId: resignation.id)
                                    }
                                } label: {
                                    if bengkelViewModel.isLoading {
                                        ProgressView()
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                    } else {
                                        Text("Approve")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.red)
                                            .cornerRadius(6)
                                    }
                                }
                                .disabled(bengkelViewModel.isLoading)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // MARK: - Job Management
                VStack(spacing: 12) {
                    NavigationLink(destination: ProviderIncomingRequestsView(
                        bengkelViewModel: bengkelViewModel,
                        selectedRequestId: $selectedRequestId,
                        showingMechanicPicker: $showingMechanicPicker
                    )) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            Text("Incoming Requests")
                                .font(.headline)
                            Spacer()
                            if bengkelViewModel.pendingRequestsCount > 0 {
                                Text("\(bengkelViewModel.pendingRequestsCount)")
                                    .font(.caption).bold()
                                    .frame(width: 24, height: 24)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: ProviderActiveRequestsView(
                        bengkelViewModel: bengkelViewModel
                    )) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Active Jobs")
                                .font(.headline)
                            Spacer()
                            if !bengkelViewModel.activeServiceRequests.isEmpty {
                                Text("\(bengkelViewModel.activeServiceRequests.count)")
                                    .font(.caption).bold()
                                    .frame(width: 24, height: 24)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                
                // MARK: - Active Promotions
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Active Promotions")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button {
                            showingCreatePromo = true
                        } label: {
                            Text("Create New Promo")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    if bengkelViewModel.providerVouchers.isEmpty {
                        Text("No active promotions.")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    } else {
                        ForEach(bengkelViewModel.providerVouchers) { voucher in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(voucher.code ?? "")
                                        .font(.headline)
                                    Text(voucher.title ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(Int(voucher.discountAmount ?? 0)) IDR")
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 2)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
        .task {
            if let uid = authViewModel.currentUser?.id {
                await bengkelViewModel.fetchMyBengkel(uid: uid)
                await bengkelViewModel.fetchProviderPromos()
                
                if let bengkelId = bengkelViewModel.myBengkel?.id {
                    await bengkelViewModel.fetchServiceRequests(bengkelId: bengkelId)
                    await bengkelViewModel.fetchTodaysEarnings(bengkelId: bengkelId)
                    await bengkelViewModel.fetchMechanics(bengkelId: bengkelId)
                    await bengkelViewModel.fetchSentInvitations(bengkelId: bengkelId)
                    await bengkelViewModel.fetchPendingResignations(bengkelId: bengkelId)
                }
            }
        }
        .sheet(isPresented: $showingCreatePromo) {
            CreatePromoSheet(bengkelViewModel: bengkelViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingAddMechanic) {
            NavigationStack {
                Form {
                    Section(header: Text("Invite by Email")) {
                        TextField("mechanic@example.com", text: $newMechanicEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Section {
                        Button {
                            Task {
                                let success = await bengkelViewModel.inviteMechanic(email: newMechanicEmail)
                                if success {
                                    newMechanicEmail = ""
                                    showingAddMechanic = false
                                }
                            }
                        } label: {
                            HStack {
                                if bengkelViewModel.isLoading {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                }
                                Text(bengkelViewModel.isLoading ? "Sending..." : "Send Invitation")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(newMechanicEmail.isEmpty || bengkelViewModel.isLoading)
                    }
                    
                    if let error = bengkelViewModel.errorMessage {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                    
                    if let success = bengkelViewModel.successMessage {
                        Section {
                            Label(success, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        }
                    }
                }
                .navigationTitle("Invite Mechanic")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            bengkelViewModel.errorMessage = nil
                            bengkelViewModel.successMessage = nil
                            showingAddMechanic = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingMechanicPicker) {
            NavigationStack {
                List(bengkelViewModel.teamMembers) { member in
                    Button(action: {
                        if let reqId = selectedRequestId {
                            Task {
                                let success = await bengkelViewModel.dispatchMechanic(requestId: reqId, mechanicId: member.id)
                                if success {
                                    if let bengkelId = bengkelViewModel.myBengkel?.id {
                                        await bengkelViewModel.fetchServiceRequests(bengkelId: bengkelId)
                                    }
                                    showingMechanicPicker = false
                                } else {
                                    showingMechanicPicker = false
                                }
                            }
                        }
                    }) {
                        HStack {
                            Text(member.name)
                            Spacer()
                            Text("Dispatch").fontWeight(.bold).foregroundColor(.blue)
                        }
                    }
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
                    } else if bengkelViewModel.teamMembers.isEmpty {
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

// MARK: - Provider Subviews

struct ProviderIncomingRequestsView: View {
    @ObservedObject var bengkelViewModel: BengkelViewModel
    @Binding var selectedRequestId: String?
    @Binding var showingMechanicPicker: Bool
    
    var body: some View {
        List {
            if bengkelViewModel.pendingRequests.isEmpty {
                Text("No incoming requests at the moment.")
                    .foregroundColor(.gray)
            } else {
                ForEach(bengkelViewModel.pendingRequests) { request in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(request.serviceType)
                                .font(.headline)
                            Spacer()
                            if request.isEmergency {
                                Text("EMERGENCY")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .cornerRadius(4)
                            }
                        }
                        
                        if let location = request.location {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Accept & Dispatch Mechanic") {
                            if let requestId = request.id {
                                selectedRequestId = requestId
                                showingMechanicPicker = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Incoming Requests")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProviderActiveRequestsView: View {
    @ObservedObject var bengkelViewModel: BengkelViewModel
    
    var body: some View {
        List {
            if bengkelViewModel.activeServiceRequests.isEmpty {
                Text("No active jobs right now.")
                    .foregroundColor(.gray)
            } else {
                ForEach(bengkelViewModel.activeServiceRequests) { active in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(active.serviceType)
                                .font(.headline)
                            Spacer()
                            Text(active.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(active.status == .inProgress ? Color.blue : Color.green)
                                .cornerRadius(8)
                        }
                        
                        if let location = active.location {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let mechanicId = active.mechanicId {
                            let mechanicName = bengkelViewModel.teamMembers.first(where: { $0.id == mechanicId })?.name ?? "Unknown Mechanic"
                            Label("Assigned to: \(mechanicName)", systemImage: "person.fill")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Text("Only the assigned mechanic can finish this job.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Active Jobs")
        .navigationBarTitleDisplayMode(.inline)
    }
}
