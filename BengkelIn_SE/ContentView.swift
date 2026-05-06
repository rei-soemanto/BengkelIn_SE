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
                    
                    PaymentPlaceholderView()
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
                    if authViewModel.isBengkelProvider {
                        Button {
                            withAnimation(.easeInOut) {
                                authViewModel.appMode = (authViewModel.appMode == .customer) ? .bengkel : .customer
                            }
                        } label: {
                            Image(systemName: authViewModel.appMode == .bengkel ? "hammer.circle.fill" : "hammer.circle")
                                .font(.title2)
                                .foregroundColor(authViewModel.appMode == .bengkel ? .orange : .gray.opacity(0.8))
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
