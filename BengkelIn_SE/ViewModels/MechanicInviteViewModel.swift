//
//  MechanicInviteViewModel.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

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
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    @discardableResult
    func respond(_ invite: MechanicInvite, accept: Bool) async -> Bool {
        errorMessage = nil
        do {
            try await mechanicRepository.respondToInvite(registrationId: invite.registrationId, accept: accept)
            await fetchInvites()
            return accept
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
}
