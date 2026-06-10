//
//  OrderTrackingView.swift
//  BengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct OrderTrackingView: View {
    let bid: Bid
    let customerCoordinate: CLLocationCoordinate2D
    let popToRoot: () -> Void

    @StateObject private var trackingViewModel = OrderTrackingViewModel()
    @StateObject private var chatWatch: ChatWatchViewModel
    @StateObject private var locationPublisher = CustomerLocationPublishViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    @State private var didPromptReview = false
    @State private var didFitBoth = false
    @State private var activeSheet: ActiveSheet?
    @State private var cancelReason = ""

    private enum ActiveSheet: Identifiable {
        case review, cancel
        var id: Int { self == .review ? 0 : 1 }
    }
    @State private var didNotifyNear = false

    init(bid: Bid, customerCoordinate: CLLocationCoordinate2D, popToRoot: @escaping () -> Void = {}) {
        self.bid = bid
        self.customerCoordinate = customerCoordinate
        self.popToRoot = popToRoot
        let initialBengkel: CLLocationCoordinate2D? = {
            guard let lat = bid.bengkel?.latitude, let lon = bid.bengkel?.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }()
        _region = State(initialValue: .fitting(customerCoordinate, initialBengkel))
        _chatWatch = StateObject(wrappedValue: ChatWatchViewModel(
            serviceRequestId: bid.serviceRequestId,
            counterpartName: bid.bengkel?.name ?? "Bengkel"
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            TrackingMapView(
                region: $region,
                customerCoordinate: customerPosition,
                bengkelCoordinate: liveBengkelCoordinate,
                bengkelName: bid.bengkel?.name ?? "Bengkel"
            )
            TrackingInfoCard(
                bid: bid,
                isLive: trackingViewModel.isLive,
                status: trackingViewModel.status,
                unreadCount: chatWatch.unreadCount,
                onOpenChat: { chatWatch.markAllRead() },
                canComplete: canCustomerComplete,
                onCancel: { activeSheet = .cancel }
            )
        }
        .navigationTitle("Bengkel Menuju Lokasi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    popToRoot()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
            }
        }
        .task { await trackingViewModel.start(serviceRequestId: bid.serviceRequestId) }
        .task { await chatWatch.start() }
        .onAppear {
            OrderRouteState.shared.enter(bid.serviceRequestId)
            evaluateProximity()
        }
        .onChange(of: trackingViewModel.order?.status) { status in
            if status == "accepted" {
                locationPublisher.start(serviceRequestId: bid.serviceRequestId)
            }
            if status == "completed" || status == "cancelled" {
                locationPublisher.stop()
            }
            if status == "completed", !trackingViewModel.alreadyRated, !didPromptReview {
                didPromptReview = true
                activeSheet = .review
            }
        }
        .onChange(of: trackingViewModel.status) { newStatus in
            if newStatus == "cancelled" {
                popToRoot()
            }
        }
        .onChange(of: trackingViewModel.providerCoordinate?.latitude) { _ in
            fitBothIfNeeded()
            evaluateProximity()
        }
        .onChange(of: locationPublisher.currentCoordinate?.latitude) { _ in
            evaluateProximity()
        }
        .onChange(of: trackingViewModel.order?.mechanicId) { _ in
            didFitBoth = false
            fitBothIfNeeded()
            evaluateProximity()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .review:
                OrderReviewSheet(
                    requestId: bid.serviceRequestId,
                    existingRating: trackingViewModel.order?.rating
                )
            case .cancel:
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pesananmu sudah diterima bengkel. Pembatalan akan ditinjau admin dan dananya ditahan sementara sampai ada keputusan.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Alasan pembatalan…", text: $cancelReason, axis: .vertical)
                            .lineLimit(3...6)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        Button {
                            Task {
                                if await trackingViewModel.openDispute(reason: cancelReason) {
                                    activeSheet = nil
                                    popToRoot()
                                }
                            }
                        } label: {
                            Text("Kirim Pembatalan")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(cancelReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1))
                                .cornerRadius(12)
                        }
                        .disabled(cancelReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if let error = trackingViewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Batalkan Pesanan")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Batal") { activeSheet = nil }
                        }
                    }
                }
                .presentationBackground(Color(.systemBackground))
                .presentationDetents([.large])
            }
        }
        .onDisappear {
            OrderRouteState.shared.leave(bid.serviceRequestId)
            trackingViewModel.stop()
            chatWatch.stop()
            locationPublisher.stop()
        }
    }

    private func fitBothIfNeeded() {
        guard !didFitBoth, let bengkel = liveBengkelCoordinate else { return }
        didFitBoth = true
        region = .fitting(customerPosition, bengkel)
    }

    private func evaluateProximity() {
        guard isBengkelNear, !didNotifyNear else { return }
        didNotifyNear = true
        trackingViewModel.notifyBengkelNear()
    }

    private var customerPosition: CLLocationCoordinate2D {
        locationPublisher.currentCoordinate ?? customerCoordinate
    }

    private var isAssigned: Bool { trackingViewModel.order?.mechanicId != nil }

    private var handlerCoordinate: CLLocationCoordinate2D? {
        trackingViewModel.providerCoordinate
    }

    private var handlerDistanceMeters: CLLocationDistance? {
        guard let p = handlerCoordinate else { return nil }
        let c = customerPosition
        return CLLocation(latitude: c.latitude, longitude: c.longitude)
            .distance(from: CLLocation(latitude: p.latitude, longitude: p.longitude))
    }
    private var isBengkelNear: Bool {
        // Both parties are placed by live GPS, so arrival uses a tight 80 m —
        // matching the bengkel side. Settlement still requires dual completion.
        if let d = handlerDistanceMeters { return d <= 80 }
        return false
    }

    private var canCustomerComplete: Bool { isAssigned && isBengkelNear }
    
    private var liveBengkelCoordinate: CLLocationCoordinate2D? {
        trackingViewModel.providerCoordinate
    }
}

#Preview {
    let bengkel = Bengkel(
        id: "preview-bengkel",
        providerUid: "preview-provider",
        name: "Bengkel Jaya Motor",
        address: "Jl. Raya Darmo No. 12, Surabaya",
        latitude: -7.2905,
        longitude: 112.6360,
        status: "Verified",
        offeredServices: [],
        averageRating: 4.8,
        totalReviews: 132
    )
    let bid = Bid(
        id: "preview-bid",
        serviceRequestId: "preview-request",
        providerUid: "preview-provider",
        bengkelId: "preview-bengkel",
        price: 75000,
        notes: "Segera meluncur ke lokasi Anda.",
        status: "Accepted",
        createdAt: nil,
        bengkel: bengkel
    )
    NavigationStack {
        OrderTrackingView(
            bid: bid,
            customerCoordinate: CLLocationCoordinate2D(latitude: -7.2845, longitude: 112.6315)
        )
    }
}
