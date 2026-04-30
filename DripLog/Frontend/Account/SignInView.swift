//
//  SignInView.swift
//  DripLog
//
//  Account/SignInView.swift
//

import SwiftUI

/// Full-screen sign-in form. Calls `viewModel.logIn()` on submit.
struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onSwitchToSignUp: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.92, green: 0.92, blue: 0.92)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Text("Welcome Back")
                        .font(.system(size: 52, weight: .bold))
                        .padding(.top, 110)

                    HStack(spacing: 2) {
                        Text("Don't have an account? ")
                        Button("Sign Up", action: onSwitchToSignUp)
                            .foregroundStyle(Color(red: 0.24, green: 0.62, blue: 0.85))
                    }
                    .font(.system(size: 18))

                    // MARK: Fields
                    VStack(spacing: 14) {
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
                            textContentType: .password
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                    }
                    .onSubmit(moveToNextField)
                    .padding(.top, 30)

                    // MARK: Primary CTA
                    Button(action: viewModel.logIn) {
                        Text(viewModel.isWorking ? "Please wait..." : "Sign in")
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

                    Button("Forgot your password?") {}
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.24, green: 0.62, blue: 0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    // MARK: Error
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.red)
                    }

                    // MARK: Social divider
                    socialDivider(text: "or sign in with")

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
        case .email:
            focusedField = .password
        default:
            focusedField = nil
            viewModel.logIn()
        }
    }
}

#Preview {
    SignInView(viewModel: AuthViewModel(), onSwitchToSignUp: {})
}