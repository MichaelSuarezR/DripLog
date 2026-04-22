//
//  AuthViewModel.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case signUp = "Sign Up"
        case logIn = "Log In"

        var id: String { rawValue }
    }

    @Published var mode: Mode = .signUp
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var currentUser: AppUser?
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var isCheckingSession = false

    private var authService: AuthServicing?

    init(authService: AuthServicing? = nil) {
        self.authService = authService
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var primaryButtonTitle: String {
        isWorking ? "Please wait..." : mode.rawValue
    }

    func loadCurrentUserIfNeeded() {
        guard currentUser == nil, !isCheckingSession else { return }

        Task {
            isCheckingSession = true
            defer { isCheckingSession = false }

            do {
                currentUser = try await service().currentUser()
            } catch {
                // Do not block the auth screen if session restore fails.
                currentUser = nil
            }
        }
    }

    func submit() {
        errorMessage = nil

        Task {
            isWorking = true
            defer { isWorking = false }

            do {
                switch mode {
                case .signUp:
                    guard password == confirmPassword else {
                        throw AuthError.passwordMismatch
                    }

                    currentUser = try await service().signUp(name: name, email: email, password: password)
                case .logIn:
                    currentUser = try await service().logIn(email: email, password: password)
                }
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
                password = ""
                confirmPassword = ""
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not log out."
            }
        }
    }

    private func service() throws -> AuthServicing {
        if let authService {
            return authService
        }

        let createdService = try SupabaseAuthService()
        authService = createdService
        return createdService
    }
}
