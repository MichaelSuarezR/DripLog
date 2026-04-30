//
//  ContentView.swift
//  DripLog
// 

import SwiftUI

/// Root router.
///
/// Flow:
///   No session  →  Account flow (Welcome → SignUp | SignIn)
///   New sign-up →  Onboarding  →  Home
///   Returning   →  Home  (directly, no onboarding)
struct ContentView: View {

    @StateObject private var authViewModel = AuthViewModel()

    /// Tracks whether the current user has already completed onboarding.
    /// Keyed by user-id so it survives log-out / log-in with a different account.
    @AppStorage("onboardingCompletedFor") private var onboardingCompletedForID: String = ""

    // Which account sub-screen to show
    @State private var accountStage: AccountStage = .welcome

    private enum AccountStage {
        case welcome, signUp, signIn
    }

    var body: some View {
        Group {
            if let user = authViewModel.currentUser {
                if authViewModel.isNewUser && !hasCompletedOnboarding(for: user.id) {
                    // Brand-new sign-up: show the tutorial first
                    OnboardingView {
                        markOnboardingComplete(for: user.id)
                    }
                } else {
                    // Returning user or onboarding already done
                    HomeView(user: user, onLogOut: authViewModel.logOut)
                }
            } else {
                accountFlow
            }
        }
        .task {
            authViewModel.loadCurrentUserIfNeeded()
        }
    }

    // MARK: - Account flow

    @ViewBuilder
    private var accountFlow: some View {
        switch accountStage {
        case .welcome:
            WelcomeView(
                onGetStarted: { accountStage = .signUp },
                onSignIn:     { accountStage = .signIn }
            )

        case .signUp:
            SignUpView(
                viewModel: authViewModel,
                onSwitchToSignIn: { accountStage = .signIn }
            )

        case .signIn:
            SignInView(
                viewModel: authViewModel,
                onSwitchToSignUp: { accountStage = .signUp }
            )
        }
    }

    // MARK: - Onboarding persistence

    private func hasCompletedOnboarding(for userID: UUID) -> Bool {
        onboardingCompletedForID == userID.uuidString
    }

    private func markOnboardingComplete(for userID: UUID) {
        onboardingCompletedForID = userID.uuidString
        // isNewUser flag is intentionally left alone; the condition above
        // now routes to Home because hasCompletedOnboarding returns true.
    }
}

#Preview {
    ContentView()
}