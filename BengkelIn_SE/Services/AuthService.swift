//
//  AuthService.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class AuthService {
    func getCurrentSession() async throws -> Session {
        return try await supabase.auth.session
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> Session {
        return try await supabase.auth.signIn(email: email, password: password)
    }

    /// Signs up a new user, writing `name` and `phone_number` into `auth.users.user_metadata`.
    /// The `users` row itself is created by a Postgres trigger on signup.
    func signUp(request: SignUpRequest) async throws {
        _ = try await supabase.auth.signUp(
            email: request.email,
            password: request.password,
            data: [
                "name": .string(request.name),
                "phone_number": .string(request.phoneNumber)
            ]
        )
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
}
