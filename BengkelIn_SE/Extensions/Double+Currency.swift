//
//  Double+Currency.swift
//  BengkelIn_SE
//
//  Global currency formatting utility.
//  Usage: someDouble.toRupiah()
//

import Foundation

extension Double {
    /// Formats the Double as Indonesian Rupiah (e.g., "Rp 150.000").
    /// This is the single source of truth for currency display across the entire app.
    /// - Returns: A formatted IDR currency string with zero decimal places.
    func toRupiah() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "Rp 0"
    }
}
