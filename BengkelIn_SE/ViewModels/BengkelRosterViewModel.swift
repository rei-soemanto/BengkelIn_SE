//
//  BengkelRosterViewModel.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class BengkelRosterViewModel: ObservableObject {
    @Published var roster: [RosterMember] = []
    @Published var inviteEmail: String = ""
    @Published var isLoading = false
    @Published var isInviting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let mechanicRepository = MechanicRepository()

    var pendingMembers: [RosterMember] { roster.filter { $0.isPending } }
    var acceptedMembers: [RosterMember] { roster.filter { $0.isAccepted } }

    func fetchRoster() async {
        isLoading = true
        errorMessage = nil
        do {
            roster = try await mechanicRepository.fetchRoster()
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    @discardableResult
    func invite() async -> Bool {
        let email = inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            errorMessage = "Masukkan email mekanik."
            return false
        }
        isInviting = true
        errorMessage = nil
        successMessage = nil
        do {
            try await mechanicRepository.inviteMechanic(email: email)
            inviteEmail = ""
            successMessage = "Undangan terkirim ke \(email)."
            await fetchRoster()
            isInviting = false
            return true
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
            isInviting = false
            return false
        }
    }

    func remove(_ member: RosterMember) async {
        errorMessage = nil
        do {
            try await mechanicRepository.removeMechanic(registrationId: member.registrationId)
            await fetchRoster()
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }
}
