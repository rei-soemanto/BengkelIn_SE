//
//  ContentView.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 01/05/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.userSession != nil {
                TabView {
                    DashboardView(authViewModel: authViewModel)
                        .tabItem {
                            Label("Dashboard", systemImage: "house.fill")
                        }
                    
                    PaymentView()
                        .tabItem {
                            Label("Payment", systemImage: "creditcard.fill")
                        }
                    
                    HistoryPlaceholderView()
                        .tabItem {
                            Label("History", systemImage: "clock.fill")
                        }
                    
                    ProfileView(authViewModel: authViewModel)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                }
                .overlay(alignment: .topTrailing) {
                    if authViewModel.isBengkelProvider || authViewModel.currentUser?.role == "MECHANIC" {
                        Menu {
                            Button("Customer Mode") {
                                withAnimation { authViewModel.appMode = .customer }
                            }
                            if authViewModel.isBengkelProvider {
                                Button("Provider Mode") {
                                    withAnimation { authViewModel.appMode = .bengkel }
                                }
                            }
                            if authViewModel.currentUser?.role == "MECHANIC" {
                                Button("Mechanic Mode") {
                                    withAnimation { authViewModel.appMode = .mechanic }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 6)
                    }
                }
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    ContentView()
}
