//
//  InvitationsView.swift
//  BengkelIn_SE
//
//  Created for Mechanic Invitation feature on 07/05/26.
//

import SwiftUI
import Combine

// MARK: - InvitationsView
// Displays pending bengkel invitations for the current mechanic user.
// Allows them to accept or reject each invitation.

struct InvitationsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var invitationVM = InvitationViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // MARK: - Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invitations")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Bengkel Offers")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                
                // MARK: - Error Banner
                if let error = invitationVM.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // MARK: - Success Banner
                if let success = invitationVM.successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(success)
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // MARK: - Loading
                if invitationVM.isLoading {
                    ProgressView("Loading invitations...")
                        .padding()
                }
                
                // MARK: - Invitations List
                if invitationVM.pendingInvitations.isEmpty && !invitationVM.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.open.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No pending invitations")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("When a bengkel invites you to join their team, it will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                } else {
                    ForEach(invitationVM.pendingInvitations) { invite in
                        invitationCard(invite)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .animation(.easeInOut, value: invitationVM.pendingInvitations.count)
        .task {
            await invitationVM.fetchPendingInvitations()
        }
        .refreshable {
            await invitationVM.fetchPendingInvitations()
        }
    }
    
    // MARK: - Invitation Card
    
    private func invitationCard(_ invite: MechanicInvitationDisplay) -> some View {
        VStack(spacing: 16) {
            // Bengkel Info
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(invite.bengkelName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("wants you to join as a Mechanic")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let createdAt = invite.createdAt {
                        Text(createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.gray)
                        + Text(" ago")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    Task {
                        _ = await invitationVM.respondToInvite(
                            inviteId: invite.id ?? "",
                            accept: false
                        )
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Decline")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                .disabled(invitationVM.isResponding)
                
                Button {
                    Task {
                        let success = await invitationVM.respondToInvite(
                            inviteId: invite.id ?? "",
                            accept: true
                        )
                        if success {
                            await authViewModel.fetchUser()
                            withAnimation {
                                authViewModel.appMode = .mechanic
                            }
                        }
                    }
                } label: {
                    HStack {
                        if invitationVM.isResponding {
                            ProgressView()
                                .tint(.white)
                        }
                        Image(systemName: "checkmark")
                        Text("Accept")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .disabled(invitationVM.isResponding)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview("Light Mode") {
    NavigationStack {
        InvitationsView(authViewModel: AuthViewModel())
    }
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    NavigationStack {
        InvitationsView(authViewModel: AuthViewModel())
    }
    .preferredColorScheme(.dark)
}
