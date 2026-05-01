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

    var body: some View {
        Group {
            if let user = authViewModel.currentUser {
                if authViewModel.isNewUser && !hasCompletedOnboarding(for: user.id) {
                    OnboardingView {
                        markOnboardingComplete(for: user.id)
                    }
                } else {
                    HomeView(user: user, onLogOut: authViewModel.logOut)
                }
            } else {
                AuthView(viewModel: authViewModel)
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
        authViewModel.completeOnboarding()
    }
}

#Preview {
    ContentView()
}

private struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private let pages = [
        "Your closet,\nbut digital",
        "See your\nfriends' fits",
        "Get AI\noutfit inspo"
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.92, green: 0.92, blue: 0.92)
                .ignoresSafeArea()

            VStack(alignment: .leading) {
                HStack(spacing: 12) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Rectangle()
                            .fill(index <= pageIndex ? Color.black.opacity(0.3) : Color.black.opacity(0.15))
                            .frame(height: 3)
                    }
                }
                .padding(.top, 70)
                .padding(.horizontal, 40)

                Spacer()

                Text(pages[pageIndex])
                    .font(.system(size: 54, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .padding(.horizontal, 40)

                Spacer()

                HStack {
                    Spacer()
                    Button(action: advance) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 70, height: 70)
                            .background(
                                Color.black.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 54)
                    .padding(.bottom, 67)
                }
            }
        }
    }

    private func advance() {
        if pageIndex < pages.count - 1 {
            pageIndex += 1
        } else {
            onFinish()
        }
    }
}
