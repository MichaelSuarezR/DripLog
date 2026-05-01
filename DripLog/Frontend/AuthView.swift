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
    @State private var stage: Stage = .welcome
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case email
        case password
        case confirmPassword
    }
    
    private enum Stage {
        case welcome
        case signUp
        case signIn
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.92, green: 0.92, blue: 0.92)
                .ignoresSafeArea()

            switch stage {
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
                            viewModel.mode = .signUp
                            stage = .signUp
                        })
                        
                        onboardingButton(title: "Sign in", action: {
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
