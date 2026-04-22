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
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case email
        case password
        case confirmPassword
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.98, blue: 0.91), Color(red: 0.84, green: 0.92, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    authCard
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DripLog")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.16))

            Text("Track the habit. Keep the streak.")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color(red: 0.26, green: 0.34, blue: 0.31))
        }
    }

    private var authCard: some View {
        VStack(spacing: 20) {
            Picker("Auth Mode", selection: $viewModel.mode) {
                ForEach(AuthViewModel.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 14) {
                if viewModel.mode == .signUp {
                    AuthTextField(
                        title: "Name",
                        text: $viewModel.name,
                        systemImage: "person"
                    )
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                }

                AuthTextField(
                    title: "Email",
                    text: $viewModel.email,
                    systemImage: "envelope",
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
                    systemImage: "lock",
                    textContentType: viewModel.mode == .signUp ? .newPassword : .password
                )
                .focused($focusedField, equals: .password)
                .submitLabel(viewModel.mode == .signUp ? .next : .go)

                if viewModel.mode == .signUp {
                    AuthSecureField(
                        title: "Confirm Password",
                        text: $viewModel.confirmPassword,
                        systemImage: "checkmark.seal",
                        textContentType: .newPassword
                    )
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                }
            }
            .onSubmit(moveToNextField)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: viewModel.submit) {
                Text(viewModel.primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color(red: 0.08, green: 0.34, blue: 0.27), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .disabled(viewModel.isWorking)
            .opacity(viewModel.isWorking ? 0.7 : 1)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 26, x: 0, y: 16)
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
    let systemImage: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        Label {
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.27))
        }
        .padding(14)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    var textContentType: UITextContentType? = nil

    var body: some View {
        Label {
            SecureField(title, text: $text)
                .textContentType(textContentType)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.27))
        }
        .padding(14)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
}
