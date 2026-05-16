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
    @State private var splashFinished = false;

    var body: some View {
        Group {
            if let user = authViewModel.currentUser, splashFinished {
                if authViewModel.isNewUser && !hasCompletedOnboarding(for: user.id) {
                    OnboardingView {
                        markOnboardingComplete(for: user.id)
                    }
                } else {
                    HomeView(
                        user: user,
                        onUserUpdated: authViewModel.replaceCurrentUser,
                        onLogOut: authViewModel.logOut
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
        authViewModel.completeOnboarding()
    }
}

#Preview {
    ContentView()
}

 
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var pageIndex = 0
 
    private let pages: [(text: String, color: Color, image: String)] = [
        ("Your Closet,\nBut Digital.",   Color(hex: 0x4597B7), "OnboardingIllustration1"),
        ("See Your\nFriends' Fits.",     Color(hex: 0xD94A2F), "OnboardingIllustration1"),
        ("Get AI\nOutfit Inspo.",        Color(hex: 0x8B8FBF), "OnboardingIllustration1"),
    ]
 
    var body: some View {
        ZStack {
            // Full-screen background color that transitions with the page
            pages[pageIndex].color
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: pageIndex)
 
            VStack(alignment: .leading, spacing: 0) {
 
                // MARK: Progress bars
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= pageIndex
                                  ? Color.white
                                  : Color.white.opacity(0.4))
                            .frame(height: 3)
                            .animation(.easeInOut(duration: 0.25), value: pageIndex)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 32)
 
                Spacer()
 
                // MARK: Headline
                Text(pages[pageIndex].text)
                    .font(.custom("GoodKitty", size: 52))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
                    .id("headline-\(pageIndex)") // forces transition on page change
                    .animation(.easeInOut(duration: 0.3), value: pageIndex)
 
                Spacer()
 
                // MARK: Illustration
                // Replace "OnboardingIllustration1/2/3" with your actual SVG asset names
                Image(pages[pageIndex].image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
                    .id("image-\(pageIndex)")
                    .animation(.easeInOut(duration: 0.3), value: pageIndex)
 
                Spacer()
 
                // MARK: Next button
                HStack {
                    Spacer()
                    Button(action: advance) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 64, height: 64)
                            .background(
                                Color.white,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 32)
                    .padding(.bottom, 60)
                }
            }
        }
    }
 
    private func advance() {
        if pageIndex < pages.count - 1 {
            withAnimation {
                pageIndex += 1
            }
        } else {
            onFinish()
        }
    }
}
 
private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}
 
#Preview {
    OnboardingView(onFinish: {})
}
