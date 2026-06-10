//
//  WithdrawalDTOs.swift
//  BengkelIn
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Foundation

// Used by UserRepository to update bank details on the users table.
struct BankDetailsUpdatePayload: Encodable {
    let bank_name: String
    let bank_account_number: String
    let bank_account_name: String
}

// Params for the request_withdrawal RPC.
struct RequestWithdrawalParams: Encodable {
    let p_amount: Double
}
