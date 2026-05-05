//
//  BengkelDashboardView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
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
                    
                    if bengkelViewModel.hasActiveJob {
                        VStack(spacing: 12) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                                .padding(.bottom, 4)
                            
                            Text(bengkelViewModel.activeJobTitle)
                                .font(.headline)
                            
                            Text(bengkelViewModel.activeJobStatus)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Button("Finish Job") {
                                bengkelViewModel.finishJob()
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
                        if bengkelViewModel.pendingRequestsCount > 0 {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                    .padding(.bottom, 4)
                                
                                Text(bengkelViewModel.incomingJobTitle)
                                    .font(.headline)
                                
                                Text(String(format: "Distance: %.1f km away", bengkelViewModel.incomingJobDistance))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Button("Accept Job Offer") {
                                    bengkelViewModel.acceptJob()
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
