//
//  AuthService.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import Foundation
import Supabase

struct AppUser: Equatable {
    let id: UUID
    let name: String
    let email: String
}

enum AuthError: LocalizedError, Equatable {
    case missingName
    case invalidEmail
    case weakPassword
    case passwordMismatch
    case missingSupabaseConfiguration

    var errorDescription: String? {
        switch self {
        case .missingName:
            "Enter your name."
        case .invalidEmail:
            "Enter a valid email address."
        case .weakPassword:
            "Password must be at least 8 characters."
        case .passwordMismatch:
            "Passwords do not match."
        case .missingSupabaseConfiguration:
            "Supabase is not configured yet. Add your project URL and anon key."
        }
    }
}

protocol AuthServicing {
    func currentUser() async throws -> AppUser?
    func signUp(name: String, email: String, password: String) async throws -> AppUser
    func logIn(email: String, password: String) async throws -> AppUser
    func logOut() async throws
}

struct MissingConfigurationAuthService: AuthServicing {
    func currentUser() async throws -> AppUser? {
        nil
    }

    func signUp(name: String, email: String, password: String) async throws -> AppUser {
        throw AuthError.missingSupabaseConfiguration
    }

    func logIn(email: String, password: String) async throws -> AppUser {
        throw AuthError.missingSupabaseConfiguration
    }

    func logOut() async throws {}
}

struct SupabaseConfiguration {
    let projectURL: URL
    let anonKey: String

    static var current: SupabaseConfiguration? {
        if
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            !urlString.isEmpty,
            let url = URL(string: urlString),
            url.scheme != nil,
            url.host != nil,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !anonKey.isEmpty
        {
            return SupabaseConfiguration(projectURL: url, anonKey: anonKey)
        }

        // Xcode's generated Info.plist does not emit arbitrary INFOPLIST_KEY_* values.
        // Keep this public anon-key fallback until project config moves to a real Info.plist or xcconfig.
        return SupabaseConfiguration(
            projectURL: URL(string: "https://yowfgdlcqtgpraizmoom.supabase.co")!,
            anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlvd2ZnZGxjcXRncHJhaXptb29tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3OTc2MDUsImV4cCI6MjA5MjM3MzYwNX0.rW8Ug2NAMaMsTD_WTVzllpZ_Yc3kBohpsD0u6wYyWGc"
        )
    }
}

struct SupabaseAuthService: AuthServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient? = nil) throws {
        self.client = try client ?? SupabaseClientProvider.makeClient()
    }

    func currentUser() async throws -> AppUser? {
        guard let session = client.auth.currentSession else {
            return nil
        }

        return try await appUser(from: session.user)
    }

    func signUp(name: String, email: String, password: String) async throws -> AppUser {
        try validateSignUp(name: name, email: email, password: password)

        let response = try await client.auth.signUp(
            email: email.normalizedEmail,
            password: password,
            data: ["name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines))]
        )

        return try await appUser(from: response.user)
    }

    func logIn(email: String, password: String) async throws -> AppUser {
        try validateLogIn(email: email, password: password)

        let session = try await client.auth.signIn(
            email: email.normalizedEmail,
            password: password
        )

        return try await appUser(from: session.user)
    }

    func logOut() async throws {
        try await client.auth.signOut()
    }

    private func appUser(from user: User) async throws -> AppUser {
        if let profile = try? await fetchProfile(for: user.id) {
            return AppUser(id: user.id, name: profile.name, email: profile.email)
        }

        return AppUser(
            id: user.id,
            name: user.userMetadata["name"]?.stringValue ?? "",
            email: user.email ?? ""
        )
    }

    private func fetchProfile(for userID: UUID) async throws -> ProfileRow {
        let response: PostgrestResponse<ProfileRow> = try await client
            .from("profiles")
            .select("id,name,email")
            .eq("id", value: userID)
            .single()
            .execute()

        return response.value
    }

    private func validateSignUp(name: String, email: String, password: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthError.missingName
        }

        try validateLogIn(email: email, password: password)
    }

    private func validateLogIn(email: String, password: String) throws {
        guard email.normalizedEmail.contains("@"), email.normalizedEmail.contains(".") else {
            throw AuthError.invalidEmail
        }

        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
    }
}

private struct ProfileRow: Decodable {
    let id: UUID
    let name: String
    let email: String
}

private extension String {
    var normalizedEmail: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
