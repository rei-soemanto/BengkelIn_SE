//
//  AuthService.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

enum AuthServiceError: LocalizedError {
    case emailAlreadyRegistered
    var errorDescription: String? {
        switch self {
        case .emailAlreadyRegistered:
            return "Email sudah terdaftar. Silakan masuk atau gunakan email lain."
        }
    }
}

class AuthService {
    func getCurrentSession() async throws -> Session {
        return try await supabase.auth.session
    }

    func currentUID() async throws -> String {
        try await supabase.auth.session.user.id.uuidString.lowercased()
    }

    func cachedSession() -> Session? {
        supabase.auth.currentSession
    }

    func authStateChanges() -> AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        AsyncStream { continuation in
            let task = Task {
                for await change in supabase.auth.authStateChanges {
                    continuation.yield((change.event, change.session))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    
    func signIn(email: String, password: String) async throws -> Session {
        return try await supabase.auth.signIn(email: email, password: password)
    }
    
    func signUp(request: SignUpRequest) async throws {
        let response = try await supabase.auth.signUp(
            email: request.email,
            password: request.password,
            data: [
                "name": .string(request.name),
                "phone_number": .string(request.phoneNumber)
            ]
        )
        if response.user.identities?.isEmpty ?? false {
            throw AuthServiceError.emailAlreadyRegistered
        }
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    func updatePhoneNumber(_ phoneNumber: String) async throws {
        _ = try await supabase.auth.update(
            user: UserAttributes(data: ["phone_number": .string(phoneNumber)])
        )
    }
}
