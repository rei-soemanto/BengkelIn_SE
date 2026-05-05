//
//  VoucherListView.swift
//  BengkelIn_SE
//
//  Created for Voucher System on 06/05/26.
//

import SwiftUI

struct VoucherListView: View {
    @ObservedObject var voucherVM: VoucherViewModel
    
    @State private var showCodeEntry = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Tab Picker
                Picker("Voucher View", selection: $selectedTab) {
                    Text("Available").tag(0)
                    Text("My Vouchers").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // MARK: - Success/Error Banners
                if let success = voucherVM.successMessage {
                    bannerView(message: success, color: .green, icon: "checkmark.circle.fill")
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation { voucherVM.successMessage = nil }
                            }
                        }
                }
                
                if let error = voucherVM.errorMessage {
                    bannerView(message: error, color: .red, icon: "exclamationmark.triangle.fill")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // MARK: - Content
                if selectedTab == 0 {
                    availableVouchersTab
                } else {
                    myVouchersTab
                }
            }
            .animation(.easeInOut, value: selectedTab)
            .navigationTitle("Vouchers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCodeEntry = true
                    } label: {
                        Image(systemName: "keyboard")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showCodeEntry) {
                VoucherEntryView(voucherVM: voucherVM)
                    .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - Available Vouchers Tab
    
    private var availableVouchersTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let activeVouchers = voucherVM.availableVouchers.filter {
                    voucherVM.isVoucherUsable($0)
                }
                
                if activeVouchers.isEmpty {
                    emptyState(
                        icon: "ticket",
                        title: "No Vouchers Available",
                        subtitle: "Check back later for new promotions."
                    )
                } else {
                    ForEach(activeVouchers) { voucher in
                        NavigationLink(destination: VoucherDetailView(voucher: voucher, voucherVM: voucherVM)) {
                            voucherCard(voucher)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - My Vouchers Tab
    
    private var myVouchersTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if voucherVM.claimedVouchers.isEmpty {
                    emptyState(
                        icon: "ticket.fill",
                        title: "No Claimed Vouchers",
                        subtitle: "Browse available vouchers or enter a code to get started."
                    )
                } else {
                    ForEach(voucherVM.claimedVouchers) { voucher in
                        NavigationLink(destination: VoucherDetailView(voucher: voucher, voucherVM: voucherVM)) {
                            voucherCard(voucher, isClaimed: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Voucher Card
    
    private func voucherCard(_ voucher: Voucher, isClaimed: Bool = false) -> some View {
        HStack(spacing: 0) {
            // Left accent strip
            Rectangle()
                .fill(accentColor(for: voucher))
                .frame(width: 6)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(voucherVM.discountDisplayText(for: voucher))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(accentColor(for: voucher))
                    
                    Spacer()
                    
                    if isClaimed {
                        Text("CLAIMED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }
                
                Text(voucher.code)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.gray)
                
                HStack(spacing: 16) {
                    if let minOrder = voucher.minimumOrderValue {
                        Label("Min. \(minOrder.toRupiah())", systemImage: "cart.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Label(expiryText(voucher.expiryDate), systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(isExpiringSoon(voucher.expiryDate) ? .orange : .secondary)
                }
                
                HStack {
                    if voucher.scope == .bengkelSpecific {
                        Label("Specific Bengkel", systemImage: "building.2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isClaimed ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
    
    // MARK: - Shared Sub-Views
    
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func bannerView(message: String, color: Color, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .foregroundColor(color)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Helpers (View-only — returns View or display strings)
    
    private func accentColor(for voucher: Voucher) -> Color {
        switch voucher.discountType {
        case .percentage: return .blue
        case .fixed: return .orange
        }
    }
    
    private func expiryText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return "Expired" }
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }
    
    private func isExpiringSoon(_ date: Date) -> Bool {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return days >= 0 && days <= 3
    }
}

#Preview("Light") {
    VoucherListView(voucherVM: VoucherViewModel())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    VoucherListView(voucherVM: VoucherViewModel())
        .preferredColorScheme(.dark)
}
