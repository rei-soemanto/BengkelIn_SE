//
//  BengkelDashboardView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI

struct BengkelDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var bengkelBiddingViewModel: BengkelBiddingViewModel

    @StateObject private var bengkelViewModel = BengkelViewModel()

    @State private var selectedOrder: NearbyOrder?
    @Environment(\.scenePhase) private var scenePhase

    var realShopRating: Double {
        bengkelViewModel.myBengkel?.averageRating ?? 0.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dasbor Penyedia")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text(bengkelViewModel.myBengkel?.name ?? "Manage Your Shop")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Penilaian Bengkel")
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

                            Text("(\(bengkelViewModel.myBengkel?.totalReviews ?? 0) Ulasan)")
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
                    Text("Pendapatan Hari Ini")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    HStack {
                        Image(systemName: "banknote.fill")
                            .foregroundColor(.green)
                            .font(.title2)

                        Text(Rupiah.format(bengkelViewModel.todaysEarnings))
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
                        Text("Permintaan Masuk")
                            .font(.title2)
                            .fontWeight(.bold)

                        Spacer()

                        if !bengkelBiddingViewModel.orders.isEmpty {
                            Text("\(bengkelBiddingViewModel.orders.count) Pending")
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                    }

                    if bengkelBiddingViewModel.myBengkel == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("Gagal memuat permintaan.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button {
                                Task { await bengkelBiddingViewModel.start() }
                            } label: {
                                Text("Coba Lagi").fontWeight(.semibold)
                                    .padding(.horizontal, 20).padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.9))
                                    .foregroundColor(Color(.systemBackground))
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else if !bengkelBiddingViewModel.hasMechanics {
                        NavigationLink(destination: ManageRosterView()) {
                            VStack(spacing: 12) {
                                Image(systemName: "person.fill.badge.plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.primary)
                                Text("Tambahkan mekanik untuk menerima order")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("Bengkel tanpa mekanik tidak akan menerima permintaan order. Undang minimal satu mekanik untuk mulai.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .padding(.horizontal)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    } else if bengkelBiddingViewModel.orders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Tidak ada permintaan masuk")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        ForEach(bengkelBiddingViewModel.orders) { order in
                            let pendingBid = bengkelBiddingViewModel.myPendingBids.first(where: { $0.serviceRequestId == order.id })
                            let wasRejected = bengkelBiddingViewModel.myRejectedBids.contains(where: { $0.serviceRequestId == order.id })
                            OrderRequestCard(
                                order: order,
                                pendingBid: pendingBid,
                                onBid: { selectedOrder = order },
                                onExpire: {
                                    Task { await bengkelBiddingViewModel.handleExpiredOrder(order) }
                                },
                                wasRejected: wasRejected
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .task {
            if let uid = authViewModel.currentUser?.id {
                await bengkelViewModel.startWatching(uid: uid)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await bengkelViewModel.loadTodaysEarnings() } }
        }
        .onDisappear {
            bengkelViewModel.stopWatching()
        }
        .sheet(item: $selectedOrder) { order in
            PlaceBidSheet(minPrice: order.price ?? 0) { price, notes in
                Task { await bengkelBiddingViewModel.placeBid(order: order, price: price, notes: notes) }
            }
        }
        .alert("Terjadi Kesalahan", isPresented: Binding(
            get: { bengkelBiddingViewModel.errorMessage != nil },
            set: { if !$0 { bengkelBiddingViewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { bengkelBiddingViewModel.errorMessage = nil }
        } message: {
            Text(bengkelBiddingViewModel.errorMessage ?? "")
        }
    }
}

#Preview ("Light Mode") {
    BengkelDashboardView(authViewModel: AuthViewModel(), bengkelBiddingViewModel: BengkelBiddingViewModel())
        .preferredColorScheme(.light)
}

#Preview ("Dark Mode") {
    BengkelDashboardView(authViewModel: AuthViewModel(), bengkelBiddingViewModel: BengkelBiddingViewModel())
        .preferredColorScheme(.dark)
}
