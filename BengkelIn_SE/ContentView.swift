//
//  ContentView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI
import Supabase
import Combine

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var network = NetworkMonitor()
    @StateObject private var bengkelBiddingViewModel = BengkelBiddingViewModel()
    // App-level so the mechanic is watched for new assignments anywhere in the app —
    // mirroring how bengkelBiddingViewModel watches incoming orders app-wide. Lives at
    // ContentView level (not inside MechanicDashboardView) so switching tabs never tears
    // down the realtime subscription.
    @StateObject private var mechanicDashboardViewModel = MechanicDashboardViewModel()
    @ObservedObject private var orderRoute = OrderRouteState.shared
    @State private var bidOrder: NearbyOrder?
    @State private var routeOrder: NearbyOrder?
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase

    private var isProvider: Bool { authViewModel.currentUser?.role == "PROVIDER" }
    private var isMechanic: Bool { authViewModel.currentUser?.role == "MECHANIC" }
    private var isBengkelMode: Bool { isProvider && authViewModel.appMode == .bengkel }

    var body: some View {
        Group {
            if !network.isConnected {
                OfflineView {
                    // Re-check connectivity. If we're back online, isConnected flips true
                    // and the .onChange below reloads the session.
                    network.recheck()
                }
            } else if authViewModel.isInitializing {
                SplashView()
            } else if authViewModel.userSession != nil {
                VStack(spacing: 0) {
                    if !orderRoute.isActive {
                        if isProvider {
                            Picker("App Mode", selection: $authViewModel.appMode) {
                                Text("Pelanggan").tag(AppMode.customer)
                                Text("Bengkel").tag(AppMode.bengkel)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                        } else if isMechanic {
                            Picker("App Mode", selection: $authViewModel.appMode) {
                                Text("Pelanggan").tag(AppMode.customer)
                                Text("Mekanik").tag(AppMode.mechanic)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                        }
                    }

                    mainTabView
                }
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .tint(.primary)
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await bengkelBiddingViewModel.refreshOnForeground() }
                Task { await mechanicDashboardViewModel.refreshOnForeground() }
            }
        }
        .onChange(of: network.isConnected) { connected in
            if connected {
                Task { await authViewModel.loadInitialSession() }
            }
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            DashboardView(authViewModel: authViewModel, bengkelBiddingViewModel: bengkelBiddingViewModel, mechanicDashboardViewModel: mechanicDashboardViewModel, onOpenSaldo: { selectedTab = 1 }, routeOrder: $routeOrder)
                .tag(0)
                .tabItem {
                    Label(
                        isBengkelMode ? "Bengkel" : "Beranda",
                        systemImage: isBengkelMode ? "wrench.and.screwdriver.fill" : "house.fill"
                    )
                }

            PaymentView()
                .tag(1)
                .tabItem {
                    Label(
                        isBengkelMode ? "Pendapatan" : "Saldo",
                        systemImage: isBengkelMode ? "banknote.fill" : "creditcard.fill"
                    )
                }

            HistoryView(authViewModel: authViewModel)
                .tag(2)
                .tabItem {
                    Label(
                        isBengkelMode ? "Pesanan" : "Riwayat",
                        systemImage: isBengkelMode ? "list.bullet.rectangle.portrait.fill" : "clock.fill"
                    )
                }

            ProfileView(authViewModel: authViewModel)
                .tag(3)
                .tabItem {
                    Label(
                        "Profil",
                        systemImage: isBengkelMode ? "person.crop.square.fill" : "person.fill"
                    )
                }
        }
        // Key on the user id, not the role: two mechanics share role "MECHANIC", so a
        // role-keyed task never re-fires on a mechanic→mechanic account switch and the
        // app-level VM stays subscribed as the previous user. Re-run per identity, and
        // reset the VM that doesn't match the current role so it can't fire stale alerts.
        .task(id: authViewModel.currentUser?.id) {
            let role = authViewModel.currentUser?.role
            if role == "MECHANIC" {
                await mechanicDashboardViewModel.start()
            } else {
                mechanicDashboardViewModel.reset()
            }
            if role == "PROVIDER" {
                await bengkelBiddingViewModel.start()
            } else {
                bengkelBiddingViewModel.reset()
            }
        }
        // Arrived-order style modal when the provider dispatches a new job to this mechanic —
        // the mechanic-side counterpart of the bengkel's IncomingJobModal, presented app-wide.
        .sheet(item: $mechanicDashboardViewModel.newAssignmentAlert) { order in
            IncomingAssignmentModal(
                order: order,
                onView: {
                    mechanicDashboardViewModel.newAssignmentAlert = nil
                    routeOrder = order
                    selectedTab = 0
                },
                onDismiss: { mechanicDashboardViewModel.newAssignmentAlert = nil }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $bengkelBiddingViewModel.newOrderAlert) { order in
            IncomingJobModal(
                order: order,
                onBid: {
                    bengkelBiddingViewModel.newOrderAlert = nil
                    bidOrder = order
                },
                onDismiss: { bengkelBiddingViewModel.newOrderAlert = nil }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $bidOrder) { order in
            PlaceBidSheet(minPrice: order.price ?? 0) { price, notes in
                Task { await bengkelBiddingViewModel.placeBid(order: order, price: price, notes: notes) }
            }
        }
        // Won-bid: route the provider to the route screen via a PUSH in the Dashboard tab
        // (not a fullScreenCover — the route screen's sheets break inside a cover).
        .onChange(of: bengkelBiddingViewModel.activeBengkelOrder?.id) { _ in
            if let order = bengkelBiddingViewModel.activeBengkelOrder {
                routeOrder = order
                selectedTab = 0
                bengkelBiddingViewModel.activeBengkelOrder = nil
            }
        }
        .alert(
            "Order Diambil",
            isPresented: Binding(
                get: { bengkelBiddingViewModel.lostBidAlert != nil },
                set: { if !$0 { bengkelBiddingViewModel.lostBidAlert = nil } }
            )
        ) {
            Button("OK", role: .cancel) { bengkelBiddingViewModel.lostBidAlert = nil }
        } message: {
            Text(bengkelBiddingViewModel.lostBidAlert ?? "")
        }
        .alert(
            "Waktu Order Habis",
            isPresented: Binding(
                get: { bengkelBiddingViewModel.expiredBidAlert != nil },
                set: { if !$0 { bengkelBiddingViewModel.expiredBidAlert = nil } }
            )
        ) {
            Button("OK", role: .cancel) { bengkelBiddingViewModel.expiredBidAlert = nil }
        } message: {
            Text(bengkelBiddingViewModel.expiredBidAlert ?? "")
        }
        .alert(
            "Tawaran Ditolak",
            isPresented: Binding(
                get: { bengkelBiddingViewModel.rejectedBidAlert != nil },
                set: { if !$0 { bengkelBiddingViewModel.rejectedBidAlert = nil } }
            )
        ) {
            Button("OK", role: .cancel) { bengkelBiddingViewModel.rejectedBidAlert = nil }
        } message: {
            Text(bengkelBiddingViewModel.rejectedBidAlert ?? "")
        }
        .alert(
            "Order Dibatalkan",
            isPresented: Binding(
                get: { bengkelBiddingViewModel.orderUnavailableAlert != nil },
                set: { if !$0 { bengkelBiddingViewModel.orderUnavailableAlert = nil } }
            )
        ) {
            Button("OK", role: .cancel) { bengkelBiddingViewModel.orderUnavailableAlert = nil }
        } message: {
            Text(bengkelBiddingViewModel.orderUnavailableAlert ?? "")
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.primary)

                Text("BengkelIn")
                    .font(.title.bold())
                    .foregroundStyle(.primary)

                ProgressView()
                    .padding(.top, 8)
            }
        }
    }
}

@MainActor
final class OrderRouteState: ObservableObject {
    static let shared = OrderRouteState()
    @Published private var activeIds: Set<String> = []
    var isActive: Bool { !activeIds.isEmpty }
    func enter(_ id: String) { activeIds.insert(id) }
    func leave(_ id: String) { activeIds.remove(id) }
}

#Preview {
    ContentView()
}
