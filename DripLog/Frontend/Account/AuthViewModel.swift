//
//  AuthViewModel.swift
//  DripLog
//
//  Account/AuthViewModel.swift
//

import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published state

    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var currentUser: AppUser?
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var isCheckingSession = false

    /// True only when the user just completed a brand-new sign-up in this
    /// session. Used by ContentView to decide whether to show onboarding.
    @Published var isNewUser = false

    private var authService: AuthServicing?

    init(authService: AuthServicing? = nil) {
        self.authService = authService
    }

    // MARK: - Computed

    var isAuthenticated: Bool { currentUser != nil }

    // MARK: - Session restore

    func loadCurrentUserIfNeeded() {
        guard currentUser == nil, !isCheckingSession else { return }

        Task {
            isCheckingSession = true
            defer { isCheckingSession = false }

            do {
                // Returning users are never treated as new — onboarding is skipped.
                currentUser = try await service().currentUser()
                isNewUser = false
            } catch {
                currentUser = nil
            }
        }
    }

    // MARK: - Auth actions

    func signUp() {
        errorMessage = nil

        Task {
            isWorking = true
            defer { isWorking = false }

            do {
                guard password == confirmPassword else {
                    throw AuthError.passwordMismatch
                }
                currentUser = try await service().signUp(name: name, email: email, password: password)
                isNewUser = true   // ← show onboarding after this
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
            }
        }
    }

    func logIn() {
        errorMessage = nil

        Task {
            isWorking = true
            defer { isWorking = false }

            do {
                currentUser = try await service().logIn(email: email, password: password)
                isNewUser = false  // ← skip onboarding, go straight to Home
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
            }
        }
    }

    func logOut() {
        Task {
            do {
                try await service().logOut()
                currentUser = nil
                isNewUser = false
                password = ""
                confirmPassword = ""
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not log out."
            }
        }
    }

    // MARK: - Private

    private func service() throws -> AuthServicing {
        if let authService { return authService }
        let created = try SupabaseAuthService()
        authService = created
        return created
    }
}