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
    // The active-order route screen is shown full-screen (not pushed) so it
    // covers the app-mode role switcher that sits above the tab bar.
    @State private var routeOrder: NearbyOrder?

    var body: some View {
        content
            .background(Color(.systemGroupedBackground))
            .task { await viewModel.loadOrders() }
            .refreshable { await viewModel.loadOrders() }
            .navigationDestination(isPresented: detailBinding) {
                if let order = viewModel.detailOrder {
                    OrderDetailView(order: order, isCustomer: false)
                }
            }
            .fullScreenCover(item: $routeOrder) { order in
                NavigationStack { BengkelRouteView(order: order) }
            }
            .sheet(item: $reportOrder) { order in
                ReportBehaviorSheet(order: order)
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
                        // Active orders open the full-screen route/work screen;
                        // finished ones push to a detail view.
                        if order.status == "accepted" {
                            routeOrder = order
                        } else {
                            viewModel.select(order)
                        }
                    }, onReport: {
                        reportOrder = order
                    })
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
