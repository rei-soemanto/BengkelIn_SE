//
//  AssignMechanicSheet.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import SwiftUI

// Provider picks a roster mechanic — or "Saya Sendiri" (Self) — for an accepted job (UC2).
// An empty roster collapses to Self only (doc UC2-2a).
struct AssignMechanicSheet: View {
    let requestId: String
    var onAssigned: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AssignMechanicViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error).font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }

                    // Self option — always available.
                    assignRow(
                        title: "Saya Sendiri",
                        subtitle: "Tangani pekerjaan ini sendiri",
                        icon: "person.fill.checkmark"
                    ) {
                        Task {
                            if await viewModel.assign(requestId: requestId, mechanicId: nil) {
                                onAssigned(); dismiss()
                            }
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView().padding(.top, 20)
                    } else if !viewModel.availableMechanics.isEmpty {
                        HStack {
                            Text("Mekanik Bengkel").font(.headline)
                            Spacer()
                        }
                        .padding(.top, 8)

                        ForEach(viewModel.availableMechanics) { mechanic in
                            assignRow(
                                title: mechanic.mechanicName,
                                subtitle: "Tugaskan ke mekanik ini",
                                icon: "wrench.and.screwdriver.fill"
                            ) {
                                Task {
                                    if await viewModel.assign(requestId: requestId, mechanicId: mechanic.mechanicId) {
                                        onAssigned(); dismiss()
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Belum ada mekanik di roster. Undang mekanik dari Profil Bengkel, atau tangani sendiri.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tugaskan Pekerjaan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
            .disabled(viewModel.isAssigning)
            .task { await viewModel.fetchAvailableMechanics() }
        }
    }

    private func assignRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Color.primary.opacity(0.8))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).fontWeight(.semibold).foregroundColor(.primary)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}
