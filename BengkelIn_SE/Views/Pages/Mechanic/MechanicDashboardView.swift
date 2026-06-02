//
//  MechanicDashboardView.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI

// Home screen shown when a MECHANIC switches to Mekanik mode. Bryan owns this shell
// (identity + entry points); the assigned-job list / active-job execution is filled in
// by Eugene's dispatch slice (see bryan-eugene-split-decision.md §P2.2 E4).
struct MechanicDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel

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

                // Assigned-job feed (Eugene's dispatch slice).
                MechanicJobsView()

                Spacer()
            }
            .padding()
        }
        .task { await authViewModel.fetchUser() }
    }
}
