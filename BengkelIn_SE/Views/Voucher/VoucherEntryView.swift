//
//  VoucherEntryView.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//

import SwiftUI

struct VoucherEntryView: View {
    @ObservedObject var voucherVM: VoucherViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var codeInput = ""
    @State private var lookupResult: Voucher?
    @State private var lookupFailed = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // MARK: - Header
                VStack(spacing: 8) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Enter Voucher Code")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Type a voucher code to check if it's valid and claim it.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
                
                // MARK: - Code Input
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(.gray)
                    
                    TextField("e.g. DARURAT20", text: $codeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .fontDesign(.monospaced)
                    
                    if !codeInput.isEmpty {
                        Button {
                            codeInput = ""
                            lookupResult = nil
                            lookupFailed = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // MARK: - Lookup Button
                Button {
                    lookupFailed = false
                    lookupResult = nil
                    
                    if let voucher = voucherVM.findVoucher(byCode: codeInput) {
                        lookupResult = voucher
                    } else {
                        lookupFailed = true
                    }
                } label: {
                    Text("Check Code")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(codeInput.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(codeInput.isEmpty)
                
                // MARK: - Result
                if lookupFailed {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("No voucher found with this code.")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                if let voucher = lookupResult {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(voucherVM.discountDisplayText(for: voucher))
                                .font(.headline)
                                .foregroundColor(voucher.discountType == .percentage ? .blue : .orange)
                            
                            Spacer()
                            
                            if voucherVM.isVoucherUsable(voucher) {
                                Text("VALID")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green)
                                    .cornerRadius(4)
                            } else {
                                Text("UNAVAILABLE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(voucher.code)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.gray)
                        
                        if voucherVM.isVoucherUsable(voucher) {
                            Button {
                                voucherVM.claimVoucher(voucherId: voucher.id, userId: "mock-user-001")
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Claim This Voucher")
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding()
            .animation(.easeInOut, value: lookupResult?.id)
            .animation(.easeInOut, value: lookupFailed)
            .navigationTitle("Enter Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    VoucherEntryView(voucherVM: VoucherViewModel())
}
