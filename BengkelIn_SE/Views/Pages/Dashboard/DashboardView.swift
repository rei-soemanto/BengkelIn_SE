//
//  DashboardView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI

enum DashboardRoute: Hashable {
    case createOrder
}

struct DashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var bengkelBiddingViewModel: BengkelBiddingViewModel
    @ObservedObject var mechanicDashboardViewModel: MechanicDashboardViewModel
    var onOpenSaldo: () -> Void = {}
    @Binding var routeOrder: NearbyOrder?
    @StateObject private var customerOrdersVM = HistoryViewModel()
    @State private var path = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                if authViewModel.appMode == .mechanic && authViewModel.currentUser?.role == "MECHANIC" {
                    MechanicDashboardView(authViewModel: authViewModel, viewModel: mechanicDashboardViewModel, onOpenRoute: { routeOrder = $0 })
                } else if authViewModel.appMode == .bengkel && authViewModel.currentUser?.role == "PROVIDER" {
                    BengkelDashboardView(authViewModel: authViewModel, bengkelBiddingViewModel: bengkelBiddingViewModel)
                } else {
                    customerDashboard
                }
            }
            .navigationDestination(for: DashboardRoute.self) { route in
                switch route {
                case .createOrder:
                    OrderView(popToRoot: { path = NavigationPath() })
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { routeOrder != nil },
                set: { if !$0 { routeOrder = nil } }
            )) {
                if let order = routeOrder { BengkelRouteView(order: order) }
            }
            .navigationDestination(isPresented: Binding(
                get: { customerOrdersVM.detailOrder != nil },
                set: { if !$0 { customerOrdersVM.detailOrder = nil; Task { await customerOrdersVM.loadOrders() } } }
            )) {
                if let order = customerOrdersVM.detailOrder {
                    OrderDetailView(order: order, isCustomer: true)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { customerOrdersVM.trackingBid != nil },
                set: { if !$0 { customerOrdersVM.trackingBid = nil; customerOrdersVM.trackingCoordinate = nil } }
            )) {
                if let bid = customerOrdersVM.trackingBid, let coordinate = customerOrdersVM.trackingCoordinate {
                    OrderTrackingView(bid: bid, customerCoordinate: coordinate, popToRoot: {
                        customerOrdersVM.trackingBid = nil
                        customerOrdersVM.trackingCoordinate = nil
                        Task { await customerOrdersVM.loadOrders() }
                    })
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { customerOrdersVM.biddingOrder != nil },
                set: { if !$0 { customerOrdersVM.biddingOrder = nil } }
            )) {
                if let order = customerOrdersVM.biddingOrder {
                    CustomerBiddingView(resuming: order, popToRoot: {
                        customerOrdersVM.biddingOrder = nil
                        Task { await customerOrdersVM.loadOrders() }
                    })
                }
            }
            .task { await authViewModel.fetchUser() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await authViewModel.fetchUser() } }
            }
        }
    }
    
    private var customerDashboard: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BengkelIn")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Hi, \(authViewModel.currentUser?.name ?? "User")!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }

                NavigationLink(value: DashboardRoute.createOrder) {
                                    HStack {
                                        Image(systemName: "wrench.and.screwdriver.fill")
                                            .font(.largeTitle)
                                        Text("Buat Pesanan")
                                            .font(.title)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundColor(Color(.systemBackground))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color.primary.opacity(0.9))
                                    .cornerRadius(16)
                                    .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
                                }

                Button(action: onOpenSaldo) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Saldo Saya")
                                .font(.subheadline)
                                .foregroundColor(Color(.systemBackground).opacity(0.8))
                            
                            Text(Rupiah.format(authViewModel.currentUser?.balance ?? 0.0))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemBackground))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(.systemBackground).opacity(0.8))
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.primary.opacity(0.9),
                                Color.primary.opacity(0.75)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Pesanan Terbaru")
                        .font(.title2)
                        .fontWeight(.bold)

                    if customerOrdersVM.orders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Belum ada pesanan")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        ForEach(customerOrdersVM.orders.prefix(3)) { order in
                            OrderHistoryRow(order: order, onTap: {
                                Task { await customerOrdersVM.select(order) }
                            })
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
        }
        .task { await customerOrdersVM.loadOrders() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await customerOrdersVM.loadOrders() } }
        }
    }
}

#Preview("Light Theme") {
    DashboardView(
        authViewModel: AuthViewModel(),
        bengkelBiddingViewModel: BengkelBiddingViewModel(),
        mechanicDashboardViewModel: MechanicDashboardViewModel(),
        routeOrder: .constant(nil)
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Theme") {
    DashboardView(
        authViewModel: AuthViewModel(),
        bengkelBiddingViewModel: BengkelBiddingViewModel(),
        mechanicDashboardViewModel: MechanicDashboardViewModel(),
        routeOrder: .constant(nil)
    )
    .preferredColorScheme(.dark)
}
