//
//  ContentView.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("onboardingCompletedFor") private var onboardingCompletedForID = ""
    @State private var splashFinished = false
    @State private var tutorialEligibleUserID = ""

    var body: some View {
        Group {
            if let user = authViewModel.currentUser, splashFinished {
                if authViewModel.isNewUser && !hasCompletedOnboarding(for: user.id) {
                    OnboardingCoordinator(
                        user: user,
                        onUserUpdated: authViewModel.replaceCurrentUser,
                        onFinish: {
                            markOnboardingComplete(for: user.id)
                        }
                    )
                } else {
                    HomeView(
                        user: user,
                        shouldRunTutorial: tutorialEligibleUserID == user.id.uuidString,
                        onUserUpdated: authViewModel.replaceCurrentUser,
                        onLogOut: {
                            tutorialEligibleUserID = ""
                            authViewModel.logOut()
                        }
                    )
                }
            } else {
                AuthView(viewModel: authViewModel, onSplashFinished: { splashFinished = true })
            }
        }
        .task {
            authViewModel.loadCurrentUserIfNeeded()
        }
    }

    private func hasCompletedOnboarding(for userID: UUID) -> Bool {
        onboardingCompletedForID == userID.uuidString
    }

    private func markOnboardingComplete(for userID: UUID) {
        onboardingCompletedForID = userID.uuidString
        tutorialEligibleUserID = userID.uuidString
        authViewModel.completeOnboarding()
    }
}

#Preview {
    ContentView()
}
