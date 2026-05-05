//
//  CreateVoucherView.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//

import SwiftUI

struct CreateVoucherView: View {
    @ObservedObject var voucherVM: VoucherViewModel
    
    let bengkelId: String
    let createdByUserId: String
    
    @Environment(\.dismiss) private var dismiss
    
    // Form fields
    @State private var code = ""
    @State private var discountType: DiscountType = .percentage
    @State private var discountValue = ""
    @State private var maxDiscountStr = ""
    @State private var minOrderStr = ""
    @State private var globalLimitStr = ""
    @State private var perUserLimit = 1
    @State private var startDate = Date()
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    @State private var isStackable = false
    @State private var eligibility: UserEligibility = .allUsers
    
    @State private var showSuccessAlert = false
    
    private var isFormValid: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(discountValue) ?? 0) > 0 &&
        expiryDate > startDate
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header
                    VStack(spacing: 8) {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Create Voucher")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Set up a discount voucher for your customers.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Code
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voucher Code")
                            .font(.headline)
                        
                        CustomInputField(
                            iconName: "number",
                            placeholder: "e.g. BENGKEL20",
                            text: $code
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        
                        Text("Must be unique. Customers will type this code.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // MARK: - Discount Type & Value
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discount")
                            .font(.headline)
                        
                        Picker("Type", selection: $discountType) {
                            Text("Percentage (%)").tag(DiscountType.percentage)
                            Text("Fixed (Rp)").tag(DiscountType.fixed)
                        }
                        .pickerStyle(.segmented)
                        
                        CustomInputField(
                            iconName: discountType == .percentage ? "percent" : "banknote",
                            placeholder: discountType == .percentage ? "e.g. 20" : "e.g. 50000",
                            text: $discountValue
                        )
                        .keyboardType(.numberPad)
                    }
                    
                    // MARK: - Caps & Minimums
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Limits")
                            .font(.headline)
                        
                        if discountType == .percentage {
                            CustomInputField(
                                iconName: "arrow.up.to.line",
                                placeholder: "Max discount amount (Rp) — optional",
                                text: $maxDiscountStr
                            )
                            .keyboardType(.numberPad)
                        }
                        
                        CustomInputField(
                            iconName: "cart.fill",
                            placeholder: "Minimum order value (Rp) — optional",
                            text: $minOrderStr
                        )
                        .keyboardType(.numberPad)
                        
                        CustomInputField(
                            iconName: "person.3.fill",
                            placeholder: "Total quota (leave empty = unlimited)",
                            text: $globalLimitStr
                        )
                        .keyboardType(.numberPad)
                        
                        Stepper("Per-user limit: \(perUserLimit)", value: $perUserLimit, in: 1...10)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // MARK: - Date Range
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Validity Period")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                            DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // MARK: - Options
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Options")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            Toggle("Stackable with other vouchers", isOn: $isStackable)
                            
                            Divider()
                            
                            Picker("User Eligibility", selection: $eligibility) {
                                Text("All Users").tag(UserEligibility.allUsers)
                                Text("New Users Only").tag(UserEligibility.newUsersOnly)
                                Text("Returning Customers").tag(UserEligibility.returningOnly)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // MARK: - Error
                    if let error = voucherVM.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                                .font(.subheadline)
                        }
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // MARK: - Submit
                    Button {
                        submitVoucher()
                    } label: {
                        Text("Create Voucher")
                            .font(.headline)
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.primary.opacity(isFormValid ? 0.9 : 0.4))
                            .cornerRadius(12)
                    }
                    .disabled(!isFormValid)
                    .padding(.top, 10)
                }
                .padding()
            }
        }
        .navigationTitle("Create Voucher")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Voucher Created!", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(voucherVM.successMessage ?? "Your voucher is now live.")
        }
    }
    
    // MARK: - Submit Logic
    
    private func submitVoucher() {
        voucherVM.errorMessage = nil
        
        let value = Double(discountValue) ?? 0
        let maxDiscount = Double(maxDiscountStr)
        let minOrder = Double(minOrderStr)
        let globalLimit = Int(globalLimitStr)
        
        voucherVM.createVoucher(
            code: code,
            discountType: discountType,
            discountValue: value,
            maxDiscount: maxDiscount,
            minOrder: minOrder,
            globalLimit: globalLimit,
            perUserLimit: perUserLimit,
            startDate: startDate,
            expiryDate: expiryDate,
            isStackable: isStackable,
            eligibility: eligibility,
            bengkelId: bengkelId,
            createdByUserId: createdByUserId
        )
        
        if voucherVM.errorMessage == nil {
            showSuccessAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        CreateVoucherView(
            voucherVM: VoucherViewModel(),
            bengkelId: "bengkel-001",
            createdByUserId: "provider-001"
        )
    }
}
