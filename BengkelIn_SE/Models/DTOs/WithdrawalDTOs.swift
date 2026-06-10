//
//  WithdrawalDTOs.swift
//  BengkelIn
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Foundation

struct BankDetailsUpdatePayload: Encodable {
    let bank_name: String
    let bank_account_number: String
    let bank_account_name: String
}

struct RequestWithdrawalParams: Encodable {
    let p_amount: Double
}
