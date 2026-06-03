//
//  AuthDTOs.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation

// Used by AuthService for sign-up metadata
struct SignUpRequest {
    let email: String
    let password: String
    let name: String
    let phoneNumber: String
}

// Used by UserRepository to update the "users" table.
// Phone number is NOT a column on `users` — it lives in auth user_metadata and is
// updated via AuthService.updatePhoneNumber, so it is intentionally absent here.
struct ProfileUpdatePayload: Encodable {
    let name: String
}

// Used by UserRepository to update profile image URL
struct ProfileImageUpdatePayload: Encodable {
    let profile_image_url: String
}
