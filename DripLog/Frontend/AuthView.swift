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
    let onSplashFinished: () -> Void
    @State private var stage: Stage = .loading

    @State private var firstName = ""
    @State private var lastName = ""

    @FocusState private var focusedSignUpField: SignUpField?
    @FocusState private var focusedSignInField: SignInField?

    private enum Stage {
        case loading
        case createAccount
        case signUp
        case signIn
    }

    private enum SignUpField: Hashable {
        case firstName, lastName, email, password, confirm
    }

    private enum SignInField: Hashable {
        case email, password
    }

    var body: some View {
        Group {
            switch stage {
            case .loading:
                loadingView
            case .createAccount:
                createAccountView
            case .signUp:
                signUpView
            case .signIn:
                signInView
            }
        }
        .onAppear {
            guard stage == .loading else { return }
            Task {
                async let minimumSplash: Void = Task.sleep(for: .milliseconds(1200))
                async let sessionCheck: Void = waitForSessionCheck()
                _ = try? await (minimumSplash, sessionCheck)

                guard stage == .loading else { return }
                onSplashFinished()

                if !viewModel.isAuthenticated {
                    stage = .createAccount
                }
            }
        }
    }

    private func waitForSessionCheck() async {
        while viewModel.isCheckingSession {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    // MARK: - Loading (Figma: 719:143)

    private var loadingView: some View {
        ZStack {
            FittyColor.loadingBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Fitty")
                    .font(FittyFont.logo(size: 50))
                    .foregroundStyle(FittyColor.cream)

                Image("FittyLoadingIllustration")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 281, height: 281)
            }
            .offset(y: -24)
        }
    }

    // MARK: - Create account (Figma: 560:551)

    private var createAccountView: some View {
        GeometryReader { geo in
            let cardHeight: CGFloat = min(454, geo.size.height * 0.52)
            let logoAreaHeight: CGFloat = geo.size.height - cardHeight

            ZStack(alignment: .bottom) {
                FittyColor.cream
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Text("Fitty")
                        .font(FittyFont.logo(size: 50))
                        .foregroundStyle(.black)
                        .padding(.top, max(geo.safeAreaInsets.top + 16, 40))

                    let illustrationSize = max(logoAreaHeight - 100, 120)
                    Image("FittyCreateAccountIllustration")
                        .resizable()
                        .scaledToFit()
                        .frame(width: illustrationSize, height: illustrationSize)
                        .padding(.top, 8)

                    Spacer(minLength: 0)
                }
                .padding(.bottom, cardHeight)

                VStack(spacing: 10) {
                    Text("Create Account")
                        .font(FittyFont.uiBold(size: 24))
                        .foregroundStyle(.black)

                    Text("Ready to get fitty?")
                        .font(FittyFont.uiLight(size: 16))
                        .foregroundStyle(.black)
                        .padding(.bottom, 8)

                    Button("Get Started") {
                        viewModel.mode = .signUp
                        viewModel.errorMessage = nil
                        stage = .signUp
                    }
                    .buttonStyle(FittyPrimaryCTAButtonStyle(height: 44, cornerRadius: 10))

                    Button("Sign in") {
                        viewModel.mode = .logIn
                        viewModel.errorMessage = nil
                        stage = .signIn
                    }
                    .buttonStyle(FittyPrimaryCTAButtonStyle(height: 44, cornerRadius: 10))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 62)
                .padding(.top, 36)
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight)
                .background(
                    FittyColor.cardWhite,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 30,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 30,
                        style: .continuous
                    )
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Sign up (Figma: 657:394)

    private var signUpView: some View {
        ZStack(alignment: .topLeading) {
            FittyColor.cream
                .ignoresSafeArea()

            Button {
                viewModel.errorMessage = nil
                stage = .createAccount
            } label: {
                Image("FittySignUpBack")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign Up")
                        .font(FittyFont.uiBold(size: 32))
                        .padding(.top, 88)

                    HStack(spacing: 0) {
                        Text("Already have an account? ")
                            .font(FittyFont.uiRegular(size: 12))
                            .foregroundStyle(Color(hex: 0x1B1919))
                        Button("Sign in") {
                            viewModel.mode = .logIn
                            viewModel.errorMessage = nil
                            stage = .signIn
                        }
                        .font(FittyFont.uiBold(size: 12))
                        .foregroundStyle(FittyColor.linkBlue)
                        .underline()
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 14) {
                        fittyTextField(title: "First Name", text: $firstName, focused: $focusedSignUpField, equals: .firstName, submit: .lastName)
                        fittyTextField(title: "Last Name", text: $lastName, focused: $focusedSignUpField, equals: .lastName, submit: .email)
                        fittyTextField(title: "Email Address", text: $viewModel.email, keyboard: .emailAddress, contentType: .emailAddress, focused: $focusedSignUpField, equals: .email, submit: .password)
                        fittySecureField(title: "Password", text: $viewModel.password, contentType: .newPassword, focused: $focusedSignUpField, equals: .password, submit: .confirm)
                        fittySecureField(title: "Re-enter Password", text: $viewModel.confirmPassword, contentType: .newPassword, focused: $focusedSignUpField, equals: .confirm, submit: nil)
                    }
                    .padding(.top, 20)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(FittyFont.uiRegular(size: 14))
                            .foregroundStyle(.red)
                    }

                    Button {
                        register()
                    } label: {
                        Text(viewModel.isWorking ? "Please wait…" : "Register")
                    }
                    .buttonStyle(FittyRegisterButtonStyle())
                    .disabled(viewModel.isWorking)
                    .padding(.top, 8)

                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(.black.opacity(0.35))
                            .frame(height: 1)
                        Text("or sign up with")
                            .font(FittyFont.uiRegular(size: 16))
                            .foregroundStyle(.black)
                            .fixedSize()
                        Rectangle()
                            .fill(.black.opacity(0.35))
                            .frame(height: 1)
                    }
                    .padding(.top, 28)

                    Button("Google") {
                        viewModel.signInWithGoogle()
                    }
                    .buttonStyle(FittyGoogleButtonStyle())
                    .padding(.top, 12)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 30)
            }
        }
    }

    // MARK: - Sign in (Figma: welcomeback 560:559)

    private var signInView: some View {
        ZStack(alignment: .topLeading) {
            FittyColor.cream
                .ignoresSafeArea()

            Button {
                viewModel.errorMessage = nil
                stage = .createAccount
            } label: {
                Image("FittySignUpBack")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Welcome Back")
                        .font(FittyFont.uiBold(size: 32))
                        .padding(.top, 88)

                    HStack(spacing: 0) {
                        Text("Don't have an account? ")
                            .font(FittyFont.uiRegular(size: 12))
                            .foregroundStyle(Color(hex: 0x1B1919))
                        Button("Sign Up") {
                            viewModel.mode = .signUp
                            viewModel.errorMessage = nil
                            stage = .signUp
                        }
                        .font(FittyFont.uiBold(size: 12))
                        .foregroundStyle(FittyColor.linkBlue)
                        .underline()
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 14) {
                        fittyTextField(title: "Email Address", text: $viewModel.email, keyboard: .emailAddress, contentType: .emailAddress, focused: $focusedSignInField, equals: .email, submit: .password)
                        fittySecureField(title: "Password", text: $viewModel.password, contentType: .password, focused: $focusedSignInField, equals: .password, submit: nil)
                    }
                    .padding(.top, 24)

                    Button("Forgot your password?") {}
                        .font(FittyFont.uiBold(size: 12))
                        .foregroundStyle(FittyColor.linkBlue)
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(FittyFont.uiRegular(size: 14))
                            .foregroundStyle(.red)
                    }

                    Button {
                        viewModel.mode = .logIn
                        viewModel.submit()
                    } label: {
                        Text(viewModel.isWorking ? "Please wait…" : "Sign in")
                    }
                    .buttonStyle(FittyRegisterButtonStyle())
                    .disabled(viewModel.isWorking)
                    .padding(.top, 8)

                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(.black.opacity(0.35))
                            .frame(height: 1)
                        Text("or sign in with")
                            .font(FittyFont.uiRegular(size: 16))
                            .foregroundStyle(.black)
                            .fixedSize()
                        Rectangle()
                            .fill(.black.opacity(0.35))
                            .frame(height: 1)
                    }
                    .padding(.top, 28)

                    Button("Google") {
                        viewModel.signInWithGoogle()
                    }
                    .buttonStyle(FittyGoogleButtonStyle())
                    .padding(.top, 12)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 30)
            }
        }
    }

    // MARK: - Actions

    private func register() {
        viewModel.mode = .signUp
        let parts = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        viewModel.name = parts.joined(separator: " ")
        viewModel.submit()
    }

    // MARK: - Fields (SignUp variants)

    private func fittyTextField(
        title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        focused: FocusState<SignUpField?>.Binding,
        equals: SignUpField,
        submit: SignUpField?
    ) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(title)
                    .font(FittyFont.uiLight(size: 14))
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.leading, 22)
            }
            TextField("", text: text)
                .font(FittyFont.uiRegular(size: 16))
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .padding(.horizontal, 22)
                .focused(focused, equals: equals)
                .submitLabel(submit == nil ? .done : .next)
                .onSubmit {
                    if let submit { focused.wrappedValue = submit }
                }
        }
        .frame(height: 44)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 4)
    }

    private func fittySecureField(
        title: String,
        text: Binding<String>,
        contentType: UITextContentType?,
        focused: FocusState<SignUpField?>.Binding,
        equals: SignUpField,
        submit: SignUpField?
    ) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(title)
                    .font(FittyFont.uiLight(size: 14))
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.leading, 22)
            }
            SecureField("", text: text)
                .font(FittyFont.uiRegular(size: 16))
                .textContentType(contentType)
                .padding(.horizontal, 22)
                .focused(focused, equals: equals)
                .submitLabel(submit == nil ? .done : .next)
                .onSubmit {
                    if let submit { focused.wrappedValue = submit }
                }
        }
        .frame(height: 44)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 4)
    }

    // MARK: - Fields (SignIn variants)

    private func fittyTextField(
        title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        focused: FocusState<SignInField?>.Binding,
        equals: SignInField,
        submit: SignInField?
    ) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(title)
                    .font(FittyFont.uiLight(size: 14))
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.leading, 22)
            }
            TextField("", text: text)
                .font(FittyFont.uiRegular(size: 16))
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 22)
                .focused(focused, equals: equals)
                .submitLabel(submit == nil ? .done : .next)
                .onSubmit {
                    if let submit { focused.wrappedValue = submit }
                }
        }
        .frame(height: 44)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 4)
    }

    private func fittySecureField(
        title: String,
        text: Binding<String>,
        contentType: UITextContentType?,
        focused: FocusState<SignInField?>.Binding,
        equals: SignInField,
        submit: SignInField?
    ) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(title)
                    .font(FittyFont.uiLight(size: 14))
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.leading, 22)
            }
            SecureField("", text: text)
                .font(FittyFont.uiRegular(size: 16))
                .textContentType(contentType)
                .padding(.horizontal, 22)
                .focused(focused, equals: equals)
                .submitLabel(submit == nil ? .done : .next)
                .onSubmit {
                    if let submit { focused.wrappedValue = submit }
                }
        }
        .frame(height: 44)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 4)
    }
}

// MARK: - Design tokens

private enum FittyColor {
    static let loadingBackground = Color(hex: 0x4597B7)
    static let cream = Color(hex: 0xF2EEE9)
    static let cardWhite = Color(hex: 0xFBFBFA)
    static let accentOrange = Color(hex: 0xD94A2F)
    static let linkBlue = Color(hex: 0x4597B7)
}

private enum FittyFont {
    // GoodKitty — PostScript name: "GoodKitty"
    static func logo(size: CGFloat) -> Font {
        .custom("GoodKitty", size: size)
    }

    // Coolvetica Bold — update "Coolvetica-Bold" to match your file's PostScript name if needed
    static func uiBold(size: CGFloat) -> Font {
        if let name = firstAvailableFont(baseNames: ["Coolvetica-Bold", "CoolveticaRg-Bold"], size: size) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .bold)
    }

    // Coolvetica Book Regular — PostScript name: "CoolveticaBk-Regular"
    static func uiRegular(size: CGFloat) -> Font {
        if let name = firstAvailableFont(baseNames: ["CoolveticaBk-Regular", "Coolvetica-Regular", "CoolveticaRg-Regular"], size: size) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .regular)
    }

    // Coolvetica Light — update if you add that weight later
    static func uiLight(size: CGFloat) -> Font {
        if let name = firstAvailableFont(baseNames: ["CoolveticaRg-Light", "Coolvetica-Light", "CoolveticaBk-Regular"], size: size) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .light)
    }

    private static func firstAvailableFont(baseNames: [String], size: CGFloat) -> String? {
        for base in baseNames where UIFont(name: base, size: size) != nil {
            return base
        }
        return nil
    }
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

private struct FittyPrimaryCTAButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FittyFont.uiRegular(size: 16))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(FittyColor.accentOrange, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

private struct FittyRegisterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FittyFont.uiRegular(size: 16))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(FittyColor.accentOrange, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

private struct FittyGoogleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FittyFont.uiRegular(size: 16))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(FittyColor.cardWhite, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 4)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel(), onSplashFinished: {})
}