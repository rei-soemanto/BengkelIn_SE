//
//  BengkelRouteView.swift
//  BengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct BengkelRouteView: View {
    let order: NearbyOrder

    @StateObject private var viewModel = BengkelRouteViewModel()
    @StateObject private var chatWatch: ChatWatchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    @State private var didFitBoth = false
    @State private var activeSheet: RouteSheet?
    @State private var reportReason = ""
    @State private var reportPhotoItem: PhotosPickerItem?
    @State private var reportPhotoData: Data?

    // A single sheet selector — two `.sheet(isPresented:)` modifiers on one view conflict
    // in SwiftUI (one flickers shut), so assign + report share one item-driven sheet.
    private enum RouteSheet: Identifiable {
        case assign, report
        var id: Int { self == .assign ? 0 : 1 }
    }

    init(order: NearbyOrder) {
        self.order = order
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: order.latitude, longitude: order.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
        _chatWatch = StateObject(wrappedValue: ChatWatchViewModel(
            serviceRequestId: order.id,
            counterpartName: order.customerName ?? "Pelanggan"
        ))
    }

    private var customerCoordinate: CLLocationCoordinate2D {
        viewModel.customerLiveCoordinate
            ?? CLLocationCoordinate2D(latitude: order.latitude, longitude: order.longitude)
    }

    private var customerDistanceMeters: CLLocationDistance? {
        guard let me = viewModel.bengkelCoordinate else { return nil }
        return CLLocation(latitude: customerCoordinate.latitude, longitude: customerCoordinate.longitude)
            .distance(from: CLLocation(latitude: me.latitude, longitude: me.longitude))
    }
    private var isCustomerNear: Bool {
        if let d = customerDistanceMeters { return d <= 80 }
        return false
    }

    // Assignment state (drives the dispatch gate). Reads the live order from the VM so it
    // reflects a just-made assignment, falling back to the order passed in.
    private var assignedMechanicId: String? {
        viewModel.order?.mechanicId ?? order.mechanicId
    }
    private var isUnassigned: Bool { assignedMechanicId == nil }
    // Provider delegated to a mechanic (someone other than the viewer) — viewer just monitors.
    private var assignedToOther: Bool {
        guard let assignee = assignedMechanicId, let me = viewModel.myUid else { return false }
        return assignee != me
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(coordinateRegion: $region, annotationItems: pins) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    VStack(spacing: 2) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(.systemBackground))
                            .padding(10)
                            .background(item.tint)
                            .clipShape(Circle())
                        Text(item.label)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.systemBackground))
                            .cornerRadius(6)
                    }
                }
            }
            controlCard
        }
        .navigationTitle("Menuju Lokasi Pelanggan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                }
            }
        }
        .task { await viewModel.start(order: order) }
        .task { await chatWatch.start() }
        .onAppear { OrderRouteState.shared.enter(order.id) }
        .onChange(of: viewModel.assigneeCoordinate?.latitude) { _ in fitBothIfNeeded() }
        // A new handler was assigned — allow the map to re-fit to the new marker.
        .onChange(of: viewModel.order?.mechanicId) { _ in didFitBoth = false }
        .onChange(of: viewModel.status) { newStatus in
            if newStatus == "cancelled" {
                dismiss()
            }
        }
        .onDisappear {
            OrderRouteState.shared.leave(order.id)
            viewModel.stop()
            chatWatch.stop()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .assign:
                AssignMechanicSheet(requestId: order.id) {
                    // After assigning, refresh the order so the gate updates immediately
                    // (the realtime watcher also picks up the change).
                    Task { await viewModel.refreshAfterAssignment() }
                }
                .presentationDetents([.medium, .large])
            case .report:
                reportSheet
            }
        }
    }

    private var reportSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Laporkan kendala yang membuat pesanan tidak bisa diselesaikan. Sertakan bukti foto. Dana ditahan untuk ditinjau admin.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("Alasan / kendala…", text: $reportReason, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                PhotosPicker(selection: $reportPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: reportPhotoData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                        Text(reportPhotoData == nil ? "Lampirkan Bukti Foto" : "Foto terlampir")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .onChange(of: reportPhotoItem) { item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            reportPhotoData = data
                        }
                    }
                }
                Button {
                    Task {
                        if await viewModel.reportIssue(reason: reportReason, photoData: reportPhotoData) {
                            activeSheet = nil
                            dismiss()
                        }
                    }
                } label: {
                    Text("Kirim Laporan")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1))
                        .cornerRadius(12)
                }
                .disabled(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding()
            .navigationTitle("Laporkan Kendala")
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

    private var pins: [TrackingPin] {
        var list = [TrackingPin(
            id: "customer",
            coordinate: customerCoordinate,
            label: "Pelanggan",
            icon: "person.fill",
            tint: .blue
        )]
        if let coord = viewModel.assigneeCoordinate {
            list.append(TrackingPin(
                id: "bengkel",
                coordinate: coord,
                label: viewModel.handlerLabel,
                icon: "car.fill",
                tint: .primary
            ))
        }
        return list
    }

    private func fitBothIfNeeded() {
        guard !didFitBoth, let me = viewModel.assigneeCoordinate else { return }
        didFitBoth = true
        region = .fitting(customerCoordinate, me)
    }

    @ViewBuilder
    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title3).foregroundColor(Color(.systemBackground))
                    .padding(10).background(Color.primary).clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.serviceType ?? order.description ?? "Servis").font(.headline.bold())
                    Text(order.customerName ?? "Pelanggan")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                // Chat exists only once a mechanic is assigned. The mechanic chats; the
                // provider can only VIEW the mechanic <-> customer thread (read-only).
                if viewModel.status == "accepted", assignedMechanicId != nil {
                    NavigationLink(destination: ChatView(
                        serviceRequestId: order.id,
                        title: order.customerName ?? "Pelanggan",
                        readOnly: !viewModel.viewerIsAssignee,
                        rightSenderId: viewModel.viewerIsAssignee ? nil : assignedMechanicId
                    )) {
                        Image(systemName: "message.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                            .overlay(alignment: .topTrailing) {
                                UnreadBadge(count: chatWatch.unreadCount)
                            }
                    }
                    .simultaneousGesture(TapGesture().onEnded { chatWatch.markAllRead() })
                } else {
                    OrderStatusBadge(status: viewModel.status)
                }
            }

            if let info = order.vehicleInfo, !info.isEmpty {
                Label(info, systemImage: "car.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            switch viewModel.status {
            case "accepted":
                if isUnassigned {
                    // Provider hasn't dispatched yet — show the assignment gate (UC2).
                    Button {
                        activeSheet = .assign
                    } label: {
                        HStack {
                            Image(systemName: "person.2.badge.gearshape.fill")
                            Text("Tugaskan Mekanik").fontWeight(.bold)
                        }
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary.opacity(0.9))
                        .cornerRadius(12)
                    }
                    reportButton
                } else if assignedToOther {
                    // Provider delegated to a mechanic — monitor only; the mechanic completes.
                    // The provider can reassign on the go if the mechanic is wrong/unavailable.
                    statusLine(text: "Ditugaskan ke mekanik. Memantau pekerjaan…",
                               icon: "person.fill.checkmark", color: .blue)
                    if viewModel.viewerIsProvider {
                        Button {
                            activeSheet = .assign
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Ganti Mekanik").fontWeight(.semibold)
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    reportButton
                } else {
                    // The dispatched mechanic does the work and completes it.
                    CompleteOrderButton(requestId: order.id, isCustomer: false, canComplete: isCustomerNear)
                    reportButton
                }
            case "completed":
                statusLine(text: "Pesanan selesai.", icon: "checkmark.seal.fill", color: .green)
            case "cancelled":
                statusLine(text: "Pesanan dibatalkan.", icon: "xmark.seal.fill", color: .red)
            default:
                statusLine(
                    text: "Tawaran terkirim. Menunggu konfirmasi pelanggan…",
                    icon: "paperplane.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 10, y: -2)
    }

    private var reportButton: some View {
        Button(role: .destructive) {
            activeSheet = .report
        } label: {
            HStack {
                Image(systemName: "exclamationmark.bubble.fill")
                Text("Laporkan Kendala").fontWeight(.semibold)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.12))
            .cornerRadius(12)
        }
    }

    private func statusLine(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text).fontWeight(.semibold)
            Spacer()
        }
        .font(.subheadline)
        .foregroundColor(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }
}
