//
//  BengkelHistoryView.swift
//  BengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI

struct BengkelHistoryView: View {
    @StateObject private var viewModel = BengkelHistoryViewModel()
    @State private var reportOrder: NearbyOrder?

    var body: some View {
        content
            .background(Color(.systemGroupedBackground))
            .task { await viewModel.loadOrders() }
            .refreshable { await viewModel.loadOrders() }
            .navigationDestination(isPresented: detailBinding) {
                if let order = viewModel.detailOrder {
                    if order.status == "accepted" {
                        BengkelRouteView(order: order)
                    } else {
                        OrderDetailView(order: order, isCustomer: false)
                    }
                }
            }
            .sheet(item: $reportOrder) { order in
                ReportBehaviorSheet(order: order) {
                    viewModel.markReported(order.id)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.orders.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.orders.isEmpty {
            HistoryEmptyState(message: "Order yang sudah kamu kerjakan akan muncul di sini.")
        } else {
            orderList
        }
    }

    private var orderList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.orders) { order in
                    OrderHistoryRow(order: order, onTap: {
                        // Active → route/work screen, finished → detail; both pushed.
                        viewModel.select(order)
                    }, onReport: {
                        reportOrder = order
                    }, hasReported: viewModel.reportedOrderIds.contains(order.id))
                }
            }
            .padding()
        }
    }

    private var detailBinding: Binding<Bool> {
        Binding(
            get: { viewModel.detailOrder != nil },
            set: { if !$0 { viewModel.detailOrder = nil } }
        )
    }
}
