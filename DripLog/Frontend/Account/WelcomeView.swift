//
//  WelcomeView.swift
//  DripLog
//
//  Account/WelcomeView.swift
//

import SwiftUI

/// The "Create Account" landing card shown after the tutorial pages.
/// Lets the user choose between signing up or logging in.
struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.92, green: 0.92, blue: 0.92)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / hero placeholder
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 333, height: 191)
                    .overlay {
                        Text("LOGO")
                            .font(.system(size: 40, weight: .bold))
                    }

                Spacer()

                // CTA card
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .overlay {
                        VStack(spacing: 18) {
                            Text("Create Account")
                                .font(.system(size: 40, weight: .bold))

                            Text("Track your closet, friends, and AI fits")
                                .font(.system(size: 18))
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 22)

                            WelcomeButton(title: "Get Started", action: onGetStarted)
                            WelcomeButton(title: "Sign in",     action: onSignIn)
                        }
                        .padding(.horizontal, 58)
                        .padding(.vertical, 34)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Sub-views

private struct WelcomeButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 28, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.black)
                .background(
                    Color.white.opacity(0.65),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeView(onGetStarted: {}, onSignIn: {})
}