//
//  PaymentService.swift
//  BengkelIn
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
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
