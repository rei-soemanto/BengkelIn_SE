//
//  CreateVoucherView.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//  Locked down pending full backend schema alignment on 07/05/26.
//

import SwiftUI

struct CreateVoucherView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "ticket.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Create Voucher")
                .font(.title)
                .fontWeight(.bold)
            
            Text("This feature is coming soon.\nVoucher creation will be available in a future update.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
        .navigationTitle("Create Voucher")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CreateVoucherView()
    }
}
