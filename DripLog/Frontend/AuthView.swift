//
//  AuthView.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import SwiftUI
import UIKit

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var stage: Stage = .tutorial
    @State private var tutorialIndex = 0
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case email
        case password
        case confirmPassword
    }
    
    private enum Stage {
        case tutorial
        case welcome
        case signUp
        case signIn
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.92, green: 0.92, blue: 0.92)
                .ignoresSafeArea()

            switch stage {
            case .tutorial:
                tutorialView
            case .welcome:
                welcomeView
            case .signUp:
                authFormView(
                    title: "Sign Up",
                    subtitlePrefix: "Already have an account? ",
                    subtitleAction: "Sign in",
                    primaryTitle: "Register",
                    socialText: "or sign up with",
                    switchAction: {
                        viewModel.mode = .logIn
                        stage = .signIn
                    }
                )
            case .signIn:
                authFormView(
                    title: "Welcome Back",
                    subtitlePrefix: "Don’t have an account? ",
                    subtitleAction: "Sign Up",
                    primaryTitle: "Sign in",
                    socialText: "or sign in with",
                    switchAction: {
                        viewModel.mode = .signUp
                        stage = .signUp
                    }
                )
            }
        }
        .onAppear(perform: syncInitialStage)
    }
    
    private func syncInitialStage() {
        if hasSeenOnboarding {
            stage = viewModel.mode == .signUp ? .signUp : .signIn
        } else {
            stage = .tutorial
        }
    }

    private var tutorialView: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(index <= tutorialIndex ? Color.black.opacity(0.3) : Color.black.opacity(0.15))
                        .frame(height: 3)
                }
            }
            .padding(.top, 70)
            .padding(.horizontal, 40)

            Spacer()
            
            Text(tutorialPages[tutorialIndex])
                .font(.system(size: 54, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .padding(.horizontal, 40)
            
            Spacer()
            
            HStack {
                Spacer()
                Button(action: nextTutorialPage) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 70, height: 70)
                        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 54)
                .padding(.bottom, 67)
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color.black.opacity(0.12))
                .frame(width: 333, height: 191)
                .overlay {
                    Text("LOGO")
                        .font(.system(size: 40, weight: .bold))
                }
            
            Spacer()
            
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
                        
                        onboardingButton(title: "Get Started", action: {
                            hasSeenOnboarding = true
                            viewModel.mode = .signUp
                            stage = .signUp
                        })
                        
                        onboardingButton(title: "Sign in", action: {
                            hasSeenOnboarding = true
                            viewModel.mode = .logIn
                            stage = .signIn
                        })
                    }
                    .padding(.horizontal, 58)
                    .padding(.vertical, 34)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private func onboardingButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 28, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.black)
                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func authFormView(
        title: String,
        subtitlePrefix: String,
        subtitleAction: String,
        primaryTitle: String,
        socialText: String,
        switchAction: @escaping () -> Void
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 52, weight: .bold))
                    .padding(.top, 110)
                
                HStack(spacing: 2) {
                    Text(subtitlePrefix)
                    Button(subtitleAction, action: switchAction)
                        .foregroundStyle(Color(red: 0.24, green: 0.62, blue: 0.85))
                }
                .font(.system(size: 18))
                
                VStack(spacing: 14) {
                    if viewModel.mode == .signUp {
                        AuthTextField(title: "First Name", text: $viewModel.name)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                    }
                    
                    AuthTextField(
                        title: "Email Address",
                        text: $viewModel.email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    .focused($focusedField, equals: .email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    
                    AuthSecureField(
                        title: "Password",
                        text: $viewModel.password,
                        textContentType: viewModel.mode == .signUp ? .newPassword : .password
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(viewModel.mode == .signUp ? .next : .go)
                    
                    if viewModel.mode == .signUp {
                        AuthSecureField(
                            title: "Re-enter Password",
                            text: $viewModel.confirmPassword,
                            textContentType: .newPassword
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                    }
                }
                .onSubmit(moveToNextField)
                .padding(.top, 30)
                
                Button(action: viewModel.submit) {
                    Text(viewModel.isWorking ? "Please wait..." : primaryTitle)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.black.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isWorking)
                .opacity(viewModel.isWorking ? 0.7 : 1)
                .padding(.top, 18)
                
                if stage == .signIn {
                    Button("Forgot your password?") {}
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.24, green: 0.62, blue: 0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                }
                
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(.black.opacity(0.4))
                        .frame(height: 1)
                    Text(socialText)
                        .font(.system(size: 34, weight: .regular))
                        .fixedSize()
                    Rectangle()
                        .fill(.black.opacity(0.4))
                        .frame(height: 1)
                }
                .padding(.top, 58)
                
                Button("Google") {}
                    .font(.system(size: 36))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .foregroundStyle(.black)
                    .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .padding(.top, 34)
                
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 30)
        }
    }
    
    private func nextTutorialPage() {
        if tutorialIndex < tutorialPages.count - 1 {
            tutorialIndex += 1
        } else {
            stage = .welcome
        }
    }

    private func moveToNextField() {
        switch focusedField {
        case .name:
            focusedField = .email
        case .email:
            focusedField = .password
        case .password where viewModel.mode == .signUp:
            focusedField = .confirmPassword
        default:
            focusedField = nil
            viewModel.submit()
        }
    }
    
    private var tutorialPages: [String] {
        [
            "Your closet,\nbut digital",
            "See your\nfriends’ fits",
            "Get AI\noutfit inspo"
        ]
    }
}

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .padding(.horizontal, 22)
            .frame(height: 62)
            .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    var textContentType: UITextContentType? = nil

    var body: some View {
        SecureField(title, text: $text)
            .textContentType(textContentType)
            .padding(.horizontal, 22)
            .frame(height: 62)
            .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
}
