//
//  MechanicHistoryView.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 03/06/26.
//

import SwiftUI

struct MechanicHistoryView: View {
    @StateObject private var viewModel = MechanicHistoryViewModel()
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
            HistoryEmptyState(message: "Order yang ditugaskan kepadamu akan muncul di sini.")
        } else {
            orderList
        }
    }

    private var orderList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.orders) { order in
                    OrderHistoryRow(order: order, onTap: {
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
