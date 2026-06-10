//
//  AuthDTOs.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

struct SignUpRequest {
    let email: String
    let password: String
    let name: String
    let phoneNumber: String
}

struct ProfileUpdatePayload: Encodable {
    let name: String
}

struct ProfileImageUpdatePayload: Encodable {
    let profile_image_url: String
}
