//
//  ManageVouchersView.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//  Locked down pending full backend schema alignment on 07/05/26.
//

import SwiftUI

struct ManageVouchersView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    let bengkelId: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "ticket.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Voucher Management")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Manage your bengkel vouchers here.\nFull management features coming soon.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            NavigationLink(destination: CreateVoucherView()) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Voucher")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .navigationTitle("Manage Vouchers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ManageVouchersView(
            authViewModel: AuthViewModel(),
            bengkelId: "bengkel-001"
        )
    }
}
