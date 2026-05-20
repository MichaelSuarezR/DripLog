import SwiftUI

struct EditAccountView: View {
    let user: AppUser
    let onUserUpdated: (AppUser) -> Void
    let onClose: () -> Void

    @AppStorage private var storedFirstName: String
    @AppStorage private var storedLastName: String
    @AppStorage private var storedEmail: String
    @State private var isPasswordVisible = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var authService: AuthServicing?

    private let backgroundColor = Color(hex: 0xF2EEE9)

    init(user: AppUser, onUserUpdated: @escaping (AppUser) -> Void, onClose: @escaping () -> Void) {
        self.user = user
        self.onUserUpdated = onUserUpdated
        self.onClose = onClose

        let nameParts = user.name.split(separator: " ", maxSplits: 1).map(String.init)
        let firstName = nameParts.first ?? ""
        let lastName = nameParts.count > 1 ? nameParts[1] : ""

        _storedFirstName = AppStorage(wrappedValue: firstName, "account.firstName.\(user.id.uuidString)")
        _storedLastName = AppStorage(wrappedValue: lastName, "account.lastName.\(user.id.uuidString)")
        _storedEmail = AppStorage(wrappedValue: user.email, "account.email.\(user.id.uuidString)")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Edit Account")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.top, 112)

                VStack(spacing: 30) {
                    EditAccountFieldRow(title: "First Name", text: $storedFirstName, placeholder: "Name Name Name")
                    EditAccountFieldRow(title: "Last Name", text: $storedLastName, placeholder: "Name Name Name")
                    EditAccountFieldRow(title: "Email Address", text: $storedEmail, placeholder: "Name Name Name", keyboard: .emailAddress)
                    EditAccountPasswordRow(isPasswordVisible: $isPasswordVisible)
                }
                .padding(.horizontal, 40)
                .padding(.top, 62)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 18)
                }

                Button(action: saveAccount) {
                    Text(isSaving ? "Saving..." : "Save Changes")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .opacity(isSaving ? 0.65 : 1)
                .padding(.horizontal, 40)
                .padding(.top, 34)

                Spacer()
            }

            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(width: 58, height: 58)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .padding(.leading, 22)
            .padding(.top, 36)
        }
    }

    private func saveAccount() {
        errorMessage = nil

        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                let updatedUser = try await service().updateAccount(
                    userID: user.id,
                    firstName: storedFirstName,
                    lastName: storedLastName,
                    email: storedEmail
                )

                storedEmail = updatedUser.email
                let nameParts = updatedUser.name.split(separator: " ", maxSplits: 1).map(String.init)
                storedFirstName = nameParts.first ?? ""
                storedLastName = nameParts.count > 1 ? nameParts[1] : ""
                onUserUpdated(updatedUser)
                onClose()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not update your account."
            }
        }
    }

    private func service() throws -> AuthServicing {
        if let authService { return authService }
        let createdService = try SupabaseAuthService()
        authService = createdService
        return createdService
    }
}

private struct EditAccountFieldRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)

                TextField(placeholder, text: $text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                    .autocorrectionDisabled(keyboard == .emailAddress)
                    .focused($isFocused)
            }

            Spacer()

            Button {
                isFocused = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(title)")
        }
        .padding(.leading, 28)
        .padding(.trailing, 23)
        .frame(height: 57)
        .background(Color.white, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 5)
    }
}

private struct EditAccountPasswordRow: View {
    @Binding var isPasswordVisible: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Password")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)

                Text(isPasswordVisible ? "Password hidden" : "dot dot dot dot dot")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.55))
            }

            Spacer()

            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
        }
        .padding(.leading, 28)
        .padding(.trailing, 23)
        .frame(height: 57)
        .background(Color.white, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 5)
    }
}

#Preview {
    EditAccountView(
        user: AppUser(id: UUID(), name: "Michael Suarez", email: "michael@example.com"),
        onUserUpdated: { _ in },
        onClose: {}
    )
}
