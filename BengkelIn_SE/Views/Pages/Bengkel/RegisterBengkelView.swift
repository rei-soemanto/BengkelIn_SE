//
//  RegisterBengkelView.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI
import MapKit

struct RegisterBengkelView: View {
    @StateObject private var viewModel = BengkelViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var bengkelName = ""
    @State private var showSuccessAlert = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Map background with center pin ──────────────────────────────
            ZStack {
                OSMMapView(
                    region: $viewModel.region,
                    isEditing: viewModel.isEditingLocation,
                    onRegionChange: { coord in
                        viewModel.updateLocationFromMap(coordinate: coord)
                    }
                )
                .ignoresSafeArea(edges: .top)

                // Static center pin
                Image(systemName: "mappin")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.red)
                    .shadow(radius: 4)
                    .offset(y: -18)
                    .allowsHitTesting(false)
            }

            // ── Bottom sheet: name + LocationInputCard + submit ─────────────
            VStack(spacing: 12) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)

                Text("Partner With Us")
                    .font(.title3.bold())

                CustomInputField(
                    iconName: "building.2",
                    placeholder: "Bengkel Name",
                    text: $bengkelName
                )

                LocationInputCard(
                    address: $viewModel.locationAddress,
                    isFocused: $viewModel.isEditingLocation,
                    isFetchingLocation: viewModel.isFetchingLocation,
                    onCurrentLocationTapped: { viewModel.useCurrentLocation() }
                )

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        let success = await viewModel.registerBengkel(name: bengkelName)
                        if success { showSuccessAlert = true }
                    }
                } label: {
                    Text("Submit for Approval")
                        .font(.headline)
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primary.opacity(canSubmit ? 0.9 : 0.4))
                        .cornerRadius(16)
                }
                .disabled(!canSubmit || viewModel.isLoading)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            )

            // ── Search overlay (covers everything while active) ─────────────
            if viewModel.isEditingLocation {
                LocationSearchView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            }

            if viewModel.isLoading {
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView("Submitting…")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .navigationTitle("Register Bengkel")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Registration Submitted!", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(viewModel.successMessage ?? "Your application is pending review.")
        }
    }

    private var canSubmit: Bool {
        !bengkelName.isEmpty && !viewModel.locationAddress.isEmpty
    }
}

#Preview("Light Mode") {
    RegisterBengkelView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    RegisterBengkelView()
        .preferredColorScheme(.dark)
}
