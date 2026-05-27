//
//  VoucherDetailView.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//  Migrated to live Supabase backend on 07/05/26.
//

import SwiftUI

struct VoucherDetailView: View {
    let voucher: Voucher
    @ObservedObject var voucherVM: VoucherViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var showClaimConfirmation = false
    
    private var isClaimed: Bool {
        voucherVM.isVoucherClaimed(voucher)
    }
    
    private var isUsable: Bool {
        voucherVM.isVoucherUsable(voucher)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Discount Header
                VStack(spacing: 8) {
                    Text(voucherVM.discountDisplayText(for: voucher))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text(voucher.code ?? "—")
                        .font(.title3)
                        .fontDesign(.monospaced)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    if !isUsable {
                        Text("This voucher is no longer available")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.top, 8)
                
                // MARK: - Terms & Conditions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms & Conditions")
                        .font(.headline)
                    
                    Divider()
                    
                    termRow(icon: "tag.fill", title: "Title",
                            value: voucher.title ?? "Promotional Voucher")
                    
                    termRow(icon: "banknote.fill", title: "Discount",
                            value: voucherVM.discountDisplayText(for: voucher))
                    
                    if let validUntil = voucher.validUntil {
                        termRow(icon: "calendar", title: "Valid Until",
                                value: formatted(validUntil))
                    }
                    
                    termRow(icon: "clock", title: "Status",
                            value: voucherVM.expiryText(for: voucher))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // MARK: - Action Button
                if isUsable {
                    if isClaimed {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Already Claimed")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        Button {
                            showClaimConfirmation = true
                        } label: {
                            HStack {
                                if voucherVM.isClaiming {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 4)
                                }
                                Image(systemName: "plus.circle.fill")
                                Text("Claim Voucher")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(voucherVM.isClaiming)
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Voucher Unavailable")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Voucher Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Claim Voucher?", isPresented: $showClaimConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Claim") {
                Task {
                    _ = await voucherVM.claimVoucher(voucherId: voucher.id ?? "")
                }
            }
        } message: {
            Text("This voucher will be added to your \"My Vouchers\" list. You can apply it during checkout.")
        }
    }
    
    // MARK: - Sub-Views
    
    private func termRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
            }
            Spacer()
        }
    }
    
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }
}
