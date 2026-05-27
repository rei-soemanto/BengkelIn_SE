//
//  UpdateBengkelView.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct UpdateBengkelView: View {
    @ObservedObject var bengkelViewModel: BengkelViewModel
    @ObservedObject var authViewModel: AuthViewModel
    var bengkel: Bengkel

    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Map background with center pin ──────────────────────────────
            ZStack {
                OSMMapView(
                    region: $bengkelViewModel.region,
                    isEditing: bengkelViewModel.isEditingLocation,
                    onRegionChange: { coord in
                        bengkelViewModel.updateLocationFromMap(coordinate: coord)
                    }
                )
                .ignoresSafeArea(edges: .top)

                Image(systemName: "mappin")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.red)
                    .shadow(radius: 4)
                    .offset(y: -18)
                    .allowsHitTesting(false)
            }

            // ── Bottom sheet ────────────────────────────────────────────────
            VStack(spacing: 12) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)

                Text("Edit Bengkel")
                    .font(.title3.bold())

                CustomInputField(iconName: "building.2", placeholder: "Bengkel Name", text: $name)

                LocationInputCard(
                    address: $bengkelViewModel.locationAddress,
                    isFocused: $bengkelViewModel.isEditingLocation,
                    isFetchingLocation: bengkelViewModel.isFetchingLocation,
                    onCurrentLocationTapped: { bengkelViewModel.useCurrentLocation() }
                )

                if let errorMessage = bengkelViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        guard let id = bengkel.id else { return }
                        let success = await bengkelViewModel.updateBengkel(bengkelId: id, name: name)
                        if success {
                            if let uid = authViewModel.currentUser?.id {
                                await bengkelViewModel.fetchMyBengkel(uid: uid)
                            }
                            dismiss()
                        }
                    }
                } label: {
                    Text("Save Changes")
                        .font(.headline)
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primary.opacity(canSave ? 0.9 : 0.4))
                        .cornerRadius(16)
                }
                .disabled(!canSave || bengkelViewModel.isLoading)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            )

            if bengkelViewModel.isEditingLocation {
                LocationSearchView(viewModel: bengkelViewModel)
                    .transition(.move(edge: .bottom))
            }

            if bengkelViewModel.isLoading {
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView("Updating…")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .navigationTitle("Edit Bengkel")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            self.name = bengkel.name
            bengkelViewModel.locationAddress = bengkel.address ?? ""
            if let lat = bengkel.latitude, let lon = bengkel.longitude {
                bengkelViewModel.region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }

    private var canSave: Bool {
        !name.isEmpty && !bengkelViewModel.locationAddress.isEmpty
    }
}
