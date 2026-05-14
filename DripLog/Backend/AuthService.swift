//
//  AuthService.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import Foundation
import Supabase
import UIKit
internal import AuthenticationServices

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
    case invalidProfilePhoto

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
        case .invalidProfilePhoto:
            "Could not prepare that profile photo."
        }
    }
}

protocol AuthServicing {
    func currentUser() async throws -> AppUser?
    func signUp(name: String, email: String, password: String) async throws -> AppUser
    func logIn(email: String, password: String) async throws -> AppUser
    func signInWithGoogle() async throws -> AppUser
    func updateAccount(userID: UUID, firstName: String, lastName: String, email: String) async throws -> AppUser
    func fetchProfilePhotoURL(for userID: UUID) async throws -> URL?
    func updateProfilePhoto(_ image: UIImage, for userID: UUID) async throws -> URL
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

    func signInWithGoogle() async throws -> AppUser {
        throw AuthError.missingSupabaseConfiguration
    }

    func updateAccount(userID: UUID, firstName: String, lastName: String, email: String) async throws -> AppUser {
        throw AuthError.missingSupabaseConfiguration
    }

    func fetchProfilePhotoURL(for userID: UUID) async throws -> URL? {
        throw AuthError.missingSupabaseConfiguration
    }

    func updateProfilePhoto(_ image: UIImage, for userID: UUID) async throws -> URL {
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
    private let profilePhotosBucket = "profile-photos"

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

    func updateAccount(userID: UUID, firstName: String, lastName: String, email: String) async throws -> AppUser {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = [trimmedFirstName, trimmedLastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let normalizedEmail = email.normalizedEmail

        guard !name.isEmpty else {
            throw AuthError.missingName
        }

        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            throw AuthError.invalidEmail
        }

        let currentEmail = client.auth.currentSession?.user.email?.normalizedEmail
        let updatedAuthUser = try await client.auth.update(
            user: UserAttributes(
                email: currentEmail == normalizedEmail ? nil : normalizedEmail,
                data: [
                    "name": .string(name),
                    "first_name": .string(trimmedFirstName),
                    "last_name": .string(trimmedLastName)
                ]
            )
        )

        let profile = ProfileUpsertRow(
            id: userID,
            firstName: trimmedFirstName,
            lastName: trimmedLastName,
            email: normalizedEmail
        )
        try await client
            .from("profiles")
            .upsert(profile, onConflict: "id")
            .execute()

        return AppUser(
            id: updatedAuthUser.id,
            name: name,
            email: normalizedEmail
        )
    }

    func fetchProfilePhotoURL(for userID: UUID) async throws -> URL? {
        let response: PostgrestResponse<ProfilePhotoRow> = try await client
            .from("profiles")
            .select("avatar_path")
            .eq("id", value: userID)
            .single()
            .execute()

        guard let avatarPath = response.value.avatarPath, !avatarPath.isEmpty else {
            return nil
        }

        return try await client.storage
            .from(profilePhotosBucket)
            .createSignedURL(path: avatarPath, expiresIn: 3600)
    }

    func updateProfilePhoto(_ image: UIImage, for userID: UUID) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw AuthError.invalidProfilePhoto
        }

        let path = "\(userID.uuidString.lowercased())/avatar.jpg"

        try await client.storage
            .from(profilePhotosBucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        try await client
            .from("profiles")
            .update(ProfilePhotoUpdate(avatarPath: path))
            .eq("id", value: userID)
            .execute()

        return try await client.storage
            .from(profilePhotosBucket)
            .createSignedURL(path: path, expiresIn: 3600)
    }

    func signInWithGoogle() async throws -> AppUser {
        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "fitty://")
        ) { webSession in
            webSession.prefersEphemeralWebBrowserSession = true
        }
        return try await appUser(from: session.user)
    }

    func logOut() async throws {
        try await client.auth.signOut()
    }

    private func appUser(from user: User) async throws -> AppUser {
        if let profile = try? await fetchProfile(for: user.id) {
            return AppUser(id: user.id, name: profile.fullName, email: profile.email)
        }

        let firstName = user.userMetadata["first_name"]?.stringValue ?? ""
        let lastName = user.userMetadata["last_name"]?.stringValue ?? ""
        let metadataName = [firstName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return AppUser(
            id: user.id,
            name: metadataName.isEmpty ? (user.userMetadata["name"]?.stringValue ?? "") : metadataName,
            email: user.email ?? ""
        )
    }

    private func fetchProfile(for userID: UUID) async throws -> ProfileRow {
        let response: PostgrestResponse<ProfileRow> = try await client
            .from("profiles")
            .select("id,first_name,last_name,email")
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
    let firstName: String?
    let lastName: String?
    let email: String

    var fullName: String {
        [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
    }
}

private struct ProfileUpsertRow: Encodable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
    }
}

private struct ProfilePhotoRow: Decodable {
    let avatarPath: String?

    enum CodingKeys: String, CodingKey {
        case avatarPath = "avatar_path"
    }
}

private struct ProfilePhotoUpdate: Encodable {
    let avatarPath: String

    enum CodingKeys: String, CodingKey {
        case avatarPath = "avatar_path"
    }
}

private extension String {
    var normalizedEmail: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

