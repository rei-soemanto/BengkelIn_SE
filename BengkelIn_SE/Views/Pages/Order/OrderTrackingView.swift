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
    @State private var hasBeenNear = false

    init(bid: Bid, customerCoordinate: CLLocationCoordinate2D, popToRoot: @escaping () -> Void = {}) {
        self.bid = bid
        self.customerCoordinate = customerCoordinate
        self.popToRoot = popToRoot
        // Default zoom matches the bengkel's route map: start centered on the
        // customer at the shared default span, then fit both once the bengkel's
        // live location arrives.
        _region = State(initialValue: .fitting(customerCoordinate, nil))
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
        // Co-located from the start (e.g. the order was placed at the bengkel,
        // no one moves): evaluate once using the known shop / order coordinates.
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
        // The customer may be the one who travels to the bengkel, so re-check
        // proximity whenever the customer's own live location moves too.
        .onChange(of: locationPublisher.currentCoordinate?.latitude) { _ in
            evaluateProximity()
        }
        // Re-check when the bengkel assigns a handler: a self-assigned, co-located
        // order becomes "arrived" the moment the assignment lands.
        .onChange(of: trackingViewModel.order?.mechanicId) { _ in
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
                .presentationBackground(.white)
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
        guard !didFitBoth, let bengkel = trackingViewModel.providerCoordinate else { return }
        didFitBoth = true
        region = .fitting(customerPosition, bengkel)
    }

    // Marks arrival sticky-true once the two parties are within range, and fires
    // the "bengkel sudah dekat" notification once. Driven by both the bengkel's
    // and the customer's location updates.
    private func evaluateProximity() {
        guard isBengkelNear else { return }
        hasBeenNear = true
        if !didNotifyNear {
            didNotifyNear = true
            trackingViewModel.notifyBengkelNear()
        }
    }

    // The customer's real position (their live fix), falling back to the order's
    // static location before the first GPS fix arrives.
    private var customerPosition: CLLocationCoordinate2D {
        locationPublisher.currentCoordinate ?? customerCoordinate
    }

    // The bengkel has assigned someone to the job once mechanic_id is set — either
    // a roster mechanic or the provider itself (assign_mechanic with no mechanic).
    private var isAssigned: Bool { trackingViewModel.order?.mechanicId != nil }
    // True when the bengkel owner (provider) is doing the work themselves, i.e.
    // the assignee is the bengkel's provider_uid.
    private var isSelfHandled: Bool {
        guard let assignee = trackingViewModel.order?.mechanicId else { return false }
        return assignee == bid.providerUid
    }

    // Position of the party actually handling the service. Their live published
    // location while travelling; if they aren't publishing yet, fall back to the
    // bengkel's fixed shop coordinate ONLY when the bengkel itself is the handler
    // (a stationary shop). A separate mechanic must be confirmed by live GPS — no
    // shop fallback, otherwise a customer standing at the shop would look "arrived"
    // while the assigned mechanic is still en route from elsewhere.
    private var handlerCoordinate: CLLocationCoordinate2D? {
        if let live = trackingViewModel.providerCoordinate { return live }
        if isSelfHandled, let lat = bid.bengkel?.latitude, let lon = bid.bengkel?.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }

    private var handlerDistanceMeters: CLLocationDistance? {
        guard let p = handlerCoordinate else { return nil }
        let c = customerPosition
        return CLLocation(latitude: c.latitude, longitude: c.longitude)
            .distance(from: CLLocation(latitude: p.latitude, longitude: p.longitude))
    }
    private var isBengkelNear: Bool {
        // 150 m, not a tight 80 m: "at the same location" (e.g. ordering from
        // within a large campus where the order pin and the bengkel's registered
        // pin differ by GPS noise + placement) must still count as arrived.
        // Safe to be generous — settlement still requires dual completion.
        if let d = handlerDistanceMeters { return d <= 150 }
        return false
    }

    // The customer may only complete once a handler is assigned AND has arrived.
    // Before assignment the status stays "Menunggu bengkel tiba di lokasi".
    private var canCustomerComplete: Bool { isAssigned && hasBeenNear }

    private var liveBengkelCoordinate: CLLocationCoordinate2D? {
        if let live = trackingViewModel.providerCoordinate { return live }
        if let lat = bid.bengkel?.latitude, let lon = bid.bengkel?.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
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
