//
//  VoucherDetailView.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//

import SwiftUI

struct VoucherDetailView: View {
    let voucher: Voucher
    @ObservedObject var voucherVM: VoucherViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var showClaimConfirmation = false
    
    private var isClaimed: Bool {
        voucherVM.userClaims.contains {
            $0.voucherId == voucher.id && $0.status == .claimed
        }
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
                        .foregroundColor(voucher.discountType == .percentage ? .blue : .orange)
                    
                    Text(voucher.code)
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
                    
                    termRow(icon: "percent", title: "Discount",
                            value: discountDescription)
                    
                    if let maxCap = voucher.maximumDiscountAmount {
                        termRow(icon: "arrow.up.to.line", title: "Maximum Discount",
                                value: maxCap.toRupiah())
                    }
                    
                    if let minOrder = voucher.minimumOrderValue {
                        termRow(icon: "cart.fill", title: "Minimum Order",
                                value: minOrder.toRupiah())
                    }
                    
                    termRow(icon: "calendar", title: "Valid Period",
                            value: "\(formatted(voucher.startDate)) – \(formatted(voucher.expiryDate))")
                    
                    termRow(icon: "person.2.fill", title: "Eligibility",
                            value: eligibilityText)
                    
                    termRow(icon: "repeat", title: "Usage Per User",
                            value: "\(voucher.perUserUsageLimit) time(s)")
                    
                    if let globalLimit = voucher.globalUsageLimit {
                        termRow(icon: "chart.bar.fill", title: "Total Quota",
                                value: "\(voucher.currentUsageCount)/\(globalLimit) used")
                    }
                    
                    termRow(icon: "building.2.fill", title: "Scope",
                            value: voucher.scope == .platformWide ? "Valid at all workshops" : "Specific workshop only")
                    
                    termRow(icon: "square.stack.fill", title: "Stackable",
                            value: voucher.isStackable ? "Can combine with other vouchers" : "Cannot combine with other vouchers")
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
                voucherVM.claimVoucher(voucherId: voucher.id, userId: "mock-user-001")
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
    
    // MARK: - Display Strings
    
    private var discountDescription: String {
        switch voucher.discountType {
        case .percentage:
            return "\(Int(voucher.discountValue))% off your order"
        case .fixed:
            return "\(voucher.discountValue.toRupiah()) off your order"
        }
    }
    
    private var eligibilityText: String {
        switch voucher.userEligibility {
        case .allUsers: return "All users"
        case .newUsersOnly: return "New users only"
        case .returningOnly: return "Returning customers only"
        }
    }
    
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        VoucherDetailView(
            voucher: VoucherViewModel().availableVouchers.first!,
            voucherVM: VoucherViewModel()
        )
    }
}
