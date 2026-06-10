//
//  AssignMechanicSheet.swift
//  BengkelIn_SE
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import SwiftUI

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

                    if viewModel.isLoading && viewModel.availableMechanics.isEmpty {
                        ProgressView().padding(.top, 30)
                    } else if viewModel.availableMechanics.isEmpty {
                        emptyState
                    } else {
                        HStack {
                            Text("Mekanik Bengkel").font(.headline)
                            Spacer()
                        }
                        ForEach(viewModel.availableMechanics) { mechanic in
                            mechanicRow(mechanic)
                        }
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
            .task { await viewModel.fetchAvailableMechanics(requestId: requestId) }
        }
    }

    private func mechanicRow(_ mechanic: AvailableMechanic) -> some View {
        let disabled = mechanic.busy || mechanic.isCurrent
        let subtitle: String = {
            if mechanic.isCurrent { return "Mekanik saat ini" }
            if mechanic.busy { return "Sedang menangani order lain" }
            return "Tugaskan ke mekanik ini"
        }()
        return Button {
            Task {
                if await viewModel.assign(requestId: requestId, mechanicId: mechanic.mechanicId) {
                    onAssigned(); dismiss()
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title3)
                    .foregroundColor(disabled ? .secondary : Color.primary.opacity(0.8))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mechanic.mechanicName)
                        .font(.body).fontWeight(.semibold)
                        .foregroundColor(disabled ? .secondary : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(mechanic.busy ? .red : .secondary)
                }
                Spacer()
                if mechanic.isCurrent {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                } else if mechanic.busy {
                    Image(systemName: "clock.badge.exclamationmark").foregroundColor(.secondary)
                } else {
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .opacity(disabled ? 0.6 : 1)
        }
        .disabled(disabled)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Belum ada mekanik di roster")
                .font(.subheadline).fontWeight(.semibold)
            Text("Undang mekanik dari Profil Bengkel untuk bisa menugaskan order ini.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
