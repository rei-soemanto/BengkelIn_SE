//
//  MechanicDashboardView.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI

// Home screen shown when a MECHANIC switches to Mekanik mode. The "Pekerjaan Aktif" feed
// updates in realtime; a brand-new assignment from the provider fires a notification and
// pops IncomingAssignmentModal — mirroring the bengkel's arrived-order experience.
struct MechanicDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MechanicDashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var jobToOpen: NearbyOrder?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mode Mekanik")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Hi, \(authViewModel.currentUser?.name ?? "Mekanik")!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Pekerjaan Aktif")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let error = viewModel.errorMessage {
                        Text(error).font(.subheadline).foregroundColor(.red)
                    }

                    if viewModel.isLoading && viewModel.jobs.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
                    } else if viewModel.jobs.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.jobs) { job in
                            Button { jobToOpen = job } label: { jobCard(job) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
        }
        .task { await viewModel.start() }
        .task { await authViewModel.fetchUser() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await viewModel.refreshOnForeground() } }
        }
        .onDisappear { viewModel.stop() }
        // Arrived-order style modal when the provider dispatches a new job in realtime.
        .sheet(item: $viewModel.newAssignmentAlert) { order in
            IncomingAssignmentModal(
                order: order,
                onView: {
                    viewModel.newAssignmentAlert = nil
                    jobToOpen = order
                },
                onDismiss: { viewModel.newAssignmentAlert = nil }
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(item: $jobToOpen) { order in
            NavigationStack { BengkelRouteView(order: order) }
        }
    }

    private func jobCard(_ job: NearbyOrder) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.title3)
                .foregroundColor(Color(.systemBackground))
                .padding(10)
                .background(Color.primary)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(job.serviceType ?? job.description ?? "Servis")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(job.customerName ?? "Pelanggan")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let info = job.vehicleInfo, !info.isEmpty {
                    Text(info).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("Belum ada pekerjaan yang ditugaskan")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Text("Pekerjaan yang ditugaskan bengkel akan muncul di sini.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
