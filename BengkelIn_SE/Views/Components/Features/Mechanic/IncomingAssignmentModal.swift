//
//  IncomingAssignmentModal.swift
//  BengkelIn_SE
//
//  Created by Bryan Fernando Dinata on 02/06/26.
//

import SwiftUI

struct IncomingAssignmentModal: View {
    let order: NearbyOrder
    let onView: () -> Void
    let onDismiss: () -> Void

    private var priceLabel: String {
        if let price = order.price { return Rupiah.format(price) }
        return "-"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)
                .padding(.top, 28)

            Text("Pekerjaan Baru Ditugaskan!")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Text(order.serviceType ?? order.description ?? "Permintaan servis")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let info = order.vehicleInfo, !info.isEmpty {
                    Label(info, systemImage: "car.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Pelanggan: \(order.customerName ?? "-")  •  \(priceLabel)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Lihat Pekerjaan", iconName: "arrow.right.circle.fill", action: onView)

                Button(action: onDismiss) {
                    Text("Nanti")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
