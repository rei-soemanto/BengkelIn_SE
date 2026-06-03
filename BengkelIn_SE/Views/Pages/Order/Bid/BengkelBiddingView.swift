//
//  BengkelBiddingView.swift
//  BengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI

struct BengkelBiddingView: View {
    @ObservedObject var viewModel: BengkelBiddingViewModel
    @State private var selectedOrder: NearbyOrder?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if viewModel.myBengkel == nil {
                    VStack(spacing: 16) {
                        BiddingEmptyState(
                            icon: "exclamationmark.triangle",
                            title: "Gagal memuat",
                            subtitle: "Order tidak dapat dimuat. Ini mungkin gangguan sementara."
                        )
                        Button {
                            Task { await viewModel.start() }
                        } label: {
                            Text("Coba Lagi")
                                .fontWeight(.semibold)
                                .foregroundColor(Color(.systemBackground))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.9))
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else if viewModel.orders.isEmpty {
                    BiddingEmptyState(
                        icon: "tray",
                        title: "Belum ada order",
                        subtitle: "Order baru di sekitar Anda akan muncul di sini."
                    )
                } else {
                    ForEach(viewModel.orders) { order in
                        let pendingBid = viewModel.myPendingBids.first(where: { $0.serviceRequestId == order.id })
                        OrderRequestCard(
                            order: order,
                            pendingBid: pendingBid,
                            onBid: {
                                selectedOrder = order
                            },
                            onExpire: {
                                Task { await viewModel.handleExpiredOrder(order) }
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Order Masuk")
        .refreshable { await viewModel.loadOrders() }
        .task { await viewModel.start() }
        .sheet(item: $selectedOrder) { order in
            PlaceBidSheet(minPrice: order.price ?? 0) { price, notes in
                Task { await viewModel.placeBid(order: order, price: price, notes: notes) }
            }
        }
        .alert("Terjadi Kesalahan", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        BengkelBiddingView(viewModel: BengkelBiddingViewModel())
    }
}
