//
//  MechanicInvitesView.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI

// Mechanic-side invite inbox (UC8). Reachable by any user from their profile, so a
// plain customer can accept an invitation and become a mechanic. Accepting refreshes
// the auth user so the Mekanik mode switcher appears immediately.
struct MechanicInvitesView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MechanicInviteViewModel()

    var body: some View {
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

                if viewModel.isLoading && viewModel.invites.isEmpty {
                    ProgressView().padding(.top, 40)
                } else if viewModel.invites.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.invites) { invite in
                        inviteCard(invite)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Undangan Mekanik")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.fetchInvites() }
    }

    private func inviteCard(_ invite: MechanicInvite) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title2)
                    .foregroundColor(Color.primary.opacity(0.8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(invite.bengkelName).font(.body).fontWeight(.semibold)
                    Text("mengundang Anda sebagai mekanik").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }

            if invite.isPending {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            let accepted = await viewModel.respond(invite, accept: true)
                            if accepted { await authViewModel.fetchUser() }
                        }
                    } label: {
                        Text("Terima")
                            .fontWeight(.semibold)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.9))
                            .cornerRadius(12)
                    }
                    Button {
                        Task { await viewModel.respond(invite, accept: false) }
                    } label: {
                        Text("Tolak")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            } else {
                Text(invite.status == "Accepted" ? "Diterima" : "Ditolak")
                    .font(.caption).fontWeight(.bold)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background((invite.status == "Accepted" ? Color.green : Color.gray).opacity(0.15))
                    .foregroundColor(invite.status == "Accepted" ? .green : .gray)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.open")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("Belum ada undangan")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
