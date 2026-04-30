//
//  SignUpView.swift
//  DripLog
//
//  Account/SignUpView.swift
//

import SwiftUI
import UIKit

/// Full-screen sign-up form. Calls `viewModel.signUp()` on submit.
struct SignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onSwitchToSignIn: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field { case name, email, password, confirmPassword }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.92, green: 0.92, blue: 0.92)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Text("Sign Up")
                        .font(.system(size: 52, weight: .bold))
                        .padding(.top, 110)

                    HStack(spacing: 2) {
                        Text("Already have an account? ")
                        Button("Sign in", action: onSwitchToSignIn)
                            .foregroundStyle(Color(red: 0.24, green: 0.62, blue: 0.85))
                    }
                    .font(.system(size: 18))

                    // MARK: Fields
                    VStack(spacing: 14) {
                        AuthTextField(title: "First Name", text: $viewModel.name)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)

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
                            textContentType: .newPassword
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)

                        AuthSecureField(
                            title: "Re-enter Password",
                            text: $viewModel.confirmPassword,
                            textContentType: .newPassword
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                    }
                    .onSubmit(moveToNextField)
                    .padding(.top, 30)

                    // MARK: Primary CTA
                    Button(action: viewModel.signUp) {
                        Text(viewModel.isWorking ? "Please wait..." : "Register")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.black.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(
                                Color.black.opacity(0.22),
                                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isWorking)
                    .opacity(viewModel.isWorking ? 0.7 : 1)
                    .padding(.top, 18)

                    // MARK: Error
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.red)
                    }

                    // MARK: Social divider
                    socialDivider(text: "or sign up with")

                    googleButton
                        .padding(.top, 34)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 30)
            }
        }
    }

    // MARK: - Field progression

    private func moveToNextField() {
        switch focusedField {
        case .name:            focusedField = .email
        case .email:           focusedField = .password
        case .password:        focusedField = .confirmPassword
        default:
            focusedField = nil
            viewModel.signUp()
        }
    }
}

// MARK: - Shared sub-views (internal to Account folder)

struct AuthTextField: View {
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
            .background(
                Color.black.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
    }
}

struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    var textContentType: UITextContentType? = nil

    var body: some View {
        SecureField(title, text: $text)
            .textContentType(textContentType)
            .padding(.horizontal, 22)
            .frame(height: 62)
            .background(
                Color.black.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
    }
}

func socialDivider(text: String) -> some View {
    HStack(spacing: 10) {
        Rectangle()
            .fill(.black.opacity(0.4))
            .frame(height: 1)
        Text(text)
            .font(.system(size: 34, weight: .regular))
            .fixedSize()
        Rectangle()
            .fill(.black.opacity(0.4))
            .frame(height: 1)
    }
    .padding(.top, 58)
}

var googleButton: some View {
    Button("Google") {}
        .font(.system(size: 36))
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .foregroundStyle(.black)
        .background(
            Color.black.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
}

#Preview {
    SignUpView(viewModel: AuthViewModel(), onSwitchToSignIn: {})
}