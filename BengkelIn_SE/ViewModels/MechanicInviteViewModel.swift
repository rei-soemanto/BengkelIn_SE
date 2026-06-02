//
//  MechanicInviteViewModel.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

// Mechanic-side invite inbox (UC8). Accepting promotes a plain USER to MECHANIC in the
// DB; the caller should refresh the auth user afterwards so the Mekanik mode appears.
@MainActor
class MechanicInviteViewModel: ObservableObject {
    @Published var invites: [MechanicInvite] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let mechanicRepository = MechanicRepository()

    var pendingInvites: [MechanicInvite] { invites.filter { $0.isPending } }
    var hasPendingInvites: Bool { !pendingInvites.isEmpty }

    func fetchInvites() async {
        isLoading = true
        errorMessage = nil
        do {
            invites = try await mechanicRepository.fetchMyInvites()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Returns true on a successful accept so the view can refresh the auth user/role.
    @discardableResult
    func respond(_ invite: MechanicInvite, accept: Bool) async -> Bool {
        errorMessage = nil
        do {
            try await mechanicRepository.respondToInvite(registrationId: invite.registrationId, accept: accept)
            await fetchInvites()
            return accept
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
