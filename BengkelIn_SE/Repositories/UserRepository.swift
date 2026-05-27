//
//  UserRepository.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 27/05/26.
//

import Foundation
import Supabase

class UserRepository {
    func fetchUser(uid: String) async throws -> User {
        return try await supabase.from("users")
            .select()
            .eq("id", value: uid)
            .single()
            .execute()
            .value
    }

    func updateProfile(uid: String, payload: ProfileUpdatePayload) async throws {
        try await supabase.from("users")
            .update(payload)
            .eq("id", value: uid)
            .execute()
    }

    func updateProfileImageUrl(uid: String, payload: ProfileImageUpdatePayload) async throws {
        try await supabase.from("users")
            .update(payload)
            .eq("id", value: uid)
            .execute()
    }

    func deleteUser(uid: String) async throws {
        try await supabase.from("users")
            .delete()
            .eq("id", value: uid)
            .execute()
    }

    /// Fetches user profiles for a given list of UUIDs (used to load a bengkel's mechanic roster).
    func fetchUsers(uids: [String]) async throws -> [User] {
        let uuidArray = uids.compactMap { UUID(uuidString: $0) }
        let response = try await supabase.from("users")
            .select()
            .in("id", values: uuidArray)
            .execute()

        return try JSONDecoder().decode([User].self, from: response.data)
    }

    /// Looks up a user by email via the secure RPC `get_user_by_email`.
    func lookupByEmail(_ email: String) async throws -> UserLookupResponse? {
        let results: [UserLookupResponse] = try await supabase
            .rpc("get_user_by_email", params: ["search_email": email])
            .execute()
            .value
        return results.first
    }
}
