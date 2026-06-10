//
//  PaymentDTOs.swift
//  BengkelIn
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Foundation

struct CreateTopupRequest: Encodable {
    let action: String
    let amount: Int
}

struct CreateTopupResponse: Decodable {
    let order_id: String
    let redirect_url: String
    let token: String
}
