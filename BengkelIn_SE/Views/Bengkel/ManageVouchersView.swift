//
//  ManageVouchersView.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//

import SwiftUI

struct ManageVouchersView: View {
    @ObservedObject var voucherVM: VoucherViewModel
    @ObservedObject var authViewModel: AuthViewModel
    
    let bengkelId: String
    
    @State private var showDeactivateAlert = false
    @State private var voucherToDeactivate: Voucher?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voucher Management")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Your Vouchers")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                
                // MARK: - Stats
                HStack(spacing: 12) {
                    StatBox(
                        title: "Active",
                        value: "\(voucherVM.bengkelVouchers.filter(\.isActive).count)",
                        icon: "ticket.fill",
                        color: .green
                    )
                    
                    StatBox(
                        title: "Total Redeemed",
                        value: "\(totalRedemptions)",
                        icon: "checkmark.circle.fill",
                        color: .blue
                    )
                }
                
                // MARK: - Success/Error
                if let success = voucherVM.successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(success)
                            .font(.subheadline)
                        Spacer()
                    }
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // MARK: - Voucher List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Issued Vouchers")
                            .font(.headline)
                        
                        Spacer()
                        
                        NavigationLink(destination: CreateVoucherView(
                            voucherVM: voucherVM,
                            bengkelId: bengkelId,
                            createdByUserId: authViewModel.currentUser?.id ?? "unknown"
                        )) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.primary)
                                .font(.title2)
                        }
                    }
                    
                    if voucherVM.bengkelVouchers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "ticket")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No vouchers created yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Tap + to create your first voucher.")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        ForEach(voucherVM.bengkelVouchers) { voucher in
                            voucherManagementRow(voucher)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .animation(.easeInOut, value: voucherVM.bengkelVouchers.count)
        .navigationTitle("Manage Vouchers")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Deactivate Voucher?", isPresented: $showDeactivateAlert) {
            Button("Cancel", role: .cancel) { voucherToDeactivate = nil }
            Button("Deactivate", role: .destructive) {
                if let voucher = voucherToDeactivate {
                    voucherVM.deactivateVoucher(voucherId: voucher.id)
                    voucherToDeactivate = nil
                }
            }
        } message: {
            Text("Users who already claimed this voucher will see it as unavailable. This cannot be undone.")
        }
    }
    
    // MARK: - Voucher Management Row
    
    private func voucherManagementRow(_ voucher: Voucher) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(voucher.code)
                    .font(.headline)
                    .fontDesign(.monospaced)
                
                Spacer()
                
                if voucher.isActive {
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .cornerRadius(4)
                } else {
                    Text("INACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray)
                        .cornerRadius(4)
                }
            }
            
            Text(voucherVM.discountDisplayText(for: voucher))
                .font(.subheadline)
                .foregroundColor(voucher.discountType == .percentage ? .blue : .orange)
            
            HStack(spacing: 16) {
                if let limit = voucher.globalUsageLimit {
                    Label("\(voucher.currentUsageCount)/\(limit) used", systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label("\(voucher.currentUsageCount) used", systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Label(voucher.expiryDate > Date() ? "Active" : "Expired", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(voucher.expiryDate > Date() ? .secondary : .red)
            }
            
            if voucher.isActive {
                Button {
                    voucherToDeactivate = voucher
                    showDeactivateAlert = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Deactivate")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(voucher.isActive ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
        )
        .opacity(voucher.isActive ? 1.0 : 0.6)
    }
    
    // MARK: - Computed
    
    private var totalRedemptions: Int {
        voucherVM.bengkelVouchers.reduce(0) { $0 + $1.currentUsageCount }
    }
}

#Preview {
    NavigationStack {
        ManageVouchersView(
            voucherVM: VoucherViewModel(),
            authViewModel: AuthViewModel(),
            bengkelId: "bengkel-001"
        )
    }
}
