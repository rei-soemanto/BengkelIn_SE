//
//  ManageRosterView.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI
struct ManageRosterView: View {
    @StateObject private var viewModel = MechanicRosterViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                inviteCard

                if let error = viewModel.errorMessage {
                    banner(text: error, icon: "exclamationmark.triangle.fill", color: .red)
                } else if let success = viewModel.successMessage {
                    banner(text: success, icon: "checkmark.circle.fill", color: .green)
                }

                if viewModel.isLoading && viewModel.roster.isEmpty {
                    ProgressView().padding(.top, 40)
                } else {
                    rosterSection(title: "Mekanik Aktif", members: viewModel.acceptedMembers,
                                  emptyText: "Belum ada mekanik aktif.")
                    rosterSection(title: "Menunggu Konfirmasi", members: viewModel.pendingMembers,
                                  emptyText: "Tidak ada undangan tertunda.")
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Kelola Mekanik")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.fetchRoster() }
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Undang Mekanik")
                .font(.headline)
            Text("Masukkan email akun mekanik untuk mengundangnya ke bengkel Anda.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                TextField("email@contoh.com", text: $viewModel.inviteEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                Button {
                    Task { await viewModel.invite() }
                } label: {
                    if viewModel.isInviting {
                        ProgressView().tint(Color(.systemBackground))
                            .frame(width: 52, height: 52)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(Color(.systemBackground))
                            .frame(width: 52, height: 52)
                    }
                }
                .background(Color.primary.opacity(viewModel.inviteEmail.isEmpty ? 0.3 : 0.9))
                .cornerRadius(12)
                .disabled(viewModel.inviteEmail.isEmpty || viewModel.isInviting)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func rosterSection(title: String, members: [RosterMember], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if members.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.mechanicName).font(.body).fontWeight(.semibold)
                            if let email = member.mechanicEmail {
                                Text(email).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if member.isPending {
                            Text("Menunggu")
                                .font(.caption2).fontWeight(.bold)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                        Button(role: .destructive) {
                            Task { await viewModel.remove(member) }
                        } label: {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func banner(text: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text).font(.subheadline)
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(10)
    }
}
