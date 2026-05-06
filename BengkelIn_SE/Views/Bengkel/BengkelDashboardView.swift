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
                                
                                Button("Accept Job Offer") {
                                    if let requestId = firstPending.id {
                                        Task {
                                            await bengkelViewModel.acceptJob(requestId: requestId)
                                        }
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
                
                // Once we have the bengkel, fetch its service requests & earnings
                if let bengkelId = bengkelViewModel.myBengkel?.id {
                    await bengkelViewModel.fetchServiceRequests(bengkelId: bengkelId)
                    await bengkelViewModel.fetchTodaysEarnings(bengkelId: bengkelId)
                }
            }
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
