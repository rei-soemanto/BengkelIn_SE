//
//  HistoryView.swift
//  BengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if authViewModel.appMode == .mechanic && authViewModel.currentUser?.role == "MECHANIC" {
                    MechanicHistoryView()
                } else if authViewModel.appMode == .bengkel && authViewModel.currentUser?.role == "PROVIDER" {
                    BengkelHistoryView()
                } else {
                    CustomerHistoryView()
                }
            }
            .navigationTitle("Riwayat Pesanan")
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    HistoryView(authViewModel: AuthViewModel())
}
