//
//  OrderStatusBadge.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 28/05/26.
//

import SwiftUI

struct OrderStatusBadge: View {
    let status: String

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case "pending": return "Mencari Bengkel"
        case "accepted": return "Berlangsung"
        case "completed": return "Selesai"
        case "cancelled": return "Dibatalkan"
        default: return status
        }
    }

    private var color: Color {
        switch status {
        case "pending": return .orange
        case "accepted": return .green
        case "completed": return .blue
        case "cancelled": return .red
        default: return .gray
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        OrderStatusBadge(status: "pending")
        OrderStatusBadge(status: "accepted")
        OrderStatusBadge(status: "completed")
        OrderStatusBadge(status: "cancelled")
    }
}
