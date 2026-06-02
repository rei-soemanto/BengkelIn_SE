//
//  PaymentService.swift
//  BengkelIn_SE
//
//  Ported from MbengkelIn (Eugene's wallet feature). Invokes the `payment`
//  edge function to start a Midtrans Snap top-up.
//

import Foundation
import Supabase

class PaymentService {
    func createTopup(amount: Int) async throws -> CreateTopupResponse {
        let body = CreateTopupRequest(action: "createTopup", amount: amount)
        let response: CreateTopupResponse = try await supabase.functions.invoke(
            "payment",
            options: FunctionInvokeOptions(body: body)
        )
        return response
    }
}
