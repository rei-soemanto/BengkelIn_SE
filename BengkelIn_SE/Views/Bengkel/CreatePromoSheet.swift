//
//  CreatePromoSheet.swift
//  BengkelIn_SE
//
//  Created for Voucher System Promo Manager.
//

import SwiftUI

struct CreatePromoSheet: View {
    @ObservedObject var bengkelViewModel: BengkelViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var code = ""
    @State private var title = ""
    @State private var discountStr = ""
    @State private var validUntil = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    
    private var isFormValid: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Double(discountStr) ?? 0) > 0 &&
        validUntil > Date()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Promo Details")) {
                    TextField("Promo Code (e.g. DISKON20)", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        
                    TextField("Title (e.g. Weekend Promo)", text: $title)
                    
                    TextField("Discount Amount (IDR)", text: $discountStr)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Validity")) {
                    DatePicker("Valid Until", selection: $validUntil, displayedComponents: [.date, .hourAndMinute])
                }
                
                if let error = bengkelViewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create New Promo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let discount = Double(discountStr) ?? 0
                        Task {
                            let success = await bengkelViewModel.createPromo(
                                code: code,
                                title: title,
                                discount: discount,
                                validUntil: validUntil
                            )
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!isFormValid || bengkelViewModel.isLoading)
                }
            }
            .overlay {
                if bengkelViewModel.isLoading {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 10)
                }
            }
        }
    }
}
