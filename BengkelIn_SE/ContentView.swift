//
//  ContentView.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 01/05/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    // MARK: - Developer Toggle (remove when backend is ready)
    // Simulates the current user having is_mechanic = true
    @State private var devMechanicMode = false
    // DEV-ONLY: E2E Diagnostics sheet toggle
    @State private var showDiagnostics = false
    
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
                    
                    // MARK: - Mechanic Tab (shown when dev toggle is ON)
                    if devMechanicMode {
                        MechanicDashboardView()
                            .tabItem {
                                Label("Mechanic", systemImage: "wrench.and.screwdriver")
                            }
                    }
                    
                    ProfileView(authViewModel: authViewModel)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                }
                .overlay(alignment: .topTrailing) {
                    // DEV-ONLY: Floating toggles
                    HStack(spacing: 8) {
                        // Diagnostics button
                        Button {
                            showDiagnostics = true
                        } label: {
                            Image(systemName: "stethoscope")
                                .font(.title2)
                                .foregroundColor(.blue.opacity(0.7))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        // Mechanic mode toggle
                        Button {
                            withAnimation(.easeInOut) {
                                devMechanicMode.toggle()
                            }
                        } label: {
                            Image(systemName: devMechanicMode ? "hammer.circle.fill" : "hammer.circle")
                                .font(.title2)
                                .foregroundColor(devMechanicMode ? .orange : .gray.opacity(0.5))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 6)
                }
                .sheet(isPresented: $showDiagnostics) {
                    E2EDiagnosticsView()
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
