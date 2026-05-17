import PhotosUI
import SwiftUI
import UIKit
import UserNotifications

struct UserProfileView: View {
    let user: AppUser
    let onUserUpdated: (AppUser) -> Void
    let onClose: () -> Void
    let onLogOut: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var notificationsEnabled = false
    @State private var isProfilePhotoUploading = false
    @State private var profilePhotoErrorMessage: String?
    @State private var isLogoutConfirmationPresented = false
    @State private var isEditAccountPresented = false
    @State private var isFriendsPresented = false
    @State private var authService: AuthServicing?

    private let backgroundColor = Color(hex: 0xF2EEE9)
    private let accentBlue = Color(hex: 0x3AA4CC)
    private let toggleBlue = Color(hex: 0x9BB3E1)
    private var notificationsStorageKey: String { "profileNotifications.\(user.id.uuidString)" }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundColor
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    titleArea
                    avatarArea
                    settingsSections
                    Spacer(minLength: 120)
                }
                .frame(maxWidth: .infinity)
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
            .padding(.top, 24)
        }
        .task {
            await loadProfilePhoto()
            await syncNotificationState()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadSelectedProfilePhoto(newItem)
            }
        }
        .confirmationDialog(
            "Are you sure you want to log out?",
            isPresented: $isLogoutConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive, action: onLogOut)
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $isEditAccountPresented) {
            EditAccountView(
                user: user,
                onUserUpdated: onUserUpdated,
                onClose: {
                    isEditAccountPresented = false
                }
            )
        }
        .fullScreenCover(isPresented: $isFriendsPresented) {
            FriendsView(user: user) {
                isFriendsPresented = false
            }
        }
    }

    private var titleArea: some View {
        Text("My Profile")
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(.black)
            .padding(.top, 68)
    }

    private var avatarArea: some View {
        VStack(spacing: 24) {
            ProfileAvatarView(image: profileImage)
                .frame(width: 178, height: 178)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text(isProfilePhotoUploading ? "Uploading..." : "Edit Photo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accentBlue)
            }
            .buttonStyle(.plain)
            .disabled(isProfilePhotoUploading)

            if let profilePhotoErrorMessage {
                Text(profilePhotoErrorMessage)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, -10)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 30)
    }

    private var settingsSections: some View {
        VStack(spacing: 0) {
            ProfileSettingsSection(title: "General", accentBlue: accentBlue) {
                ProfileSettingsRow(icon: "person", title: "Account", accentBlue: accentBlue) {
                    isEditAccountPresented = true
                }
                ProfileSettingsRow(icon: "person.2", title: "Friends", accentBlue: accentBlue) {
                    isFriendsPresented = true
                }
                ProfileToggleRow(
                    icon: "bell",
                    title: "Notifications",
                    isOn: Binding(
                        get: { notificationsEnabled },
                        set: { newValue in
                            updateNotifications(enabled: newValue)
                        }
                    ),
                    accentBlue: accentBlue,
                    toggleBlue: toggleBlue
                )
                ProfileSettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Logout", accentBlue: accentBlue) {
                    isLogoutConfirmationPresented = true
                }
            }

            ProfileSettingsSection(title: "Feedback", accentBlue: accentBlue) {
                ProfileSettingsRow(icon: "ladybug", title: "Report a bug", accentBlue: accentBlue) {}
                ProfileSettingsRow(icon: "megaphone", title: "Feedback", accentBlue: accentBlue) {}
            }
            .padding(.top, 41)
        }
    }

    private func loadProfilePhoto() async {
        do {
            guard
                let url = try await service().fetchProfilePhotoURL(for: user.id),
                let (data, _) = try? await URLSession.shared.data(from: url),
                let image = UIImage(data: data)
            else { return }

            await MainActor.run {
                profileImage = image
            }
        } catch {
            await MainActor.run {
                profilePhotoErrorMessage = nil
            }
        }
    }

    @MainActor
    private func loadSelectedProfilePhoto(_ item: PhotosPickerItem?) async {
        profilePhotoErrorMessage = nil

        guard
            let item,
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }

        profileImage = image

        isProfilePhotoUploading = true
        defer { isProfilePhotoUploading = false }

        do {
            let signedURL = try await service().updateProfilePhoto(image, for: user.id)
            if
                let (data, _) = try? await URLSession.shared.data(from: signedURL),
                let refreshedImage = UIImage(data: data)
            {
                profileImage = refreshedImage
            }
        } catch {
            profilePhotoErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not update your profile photo."
        }
    }

    private func syncNotificationState() async {
        let storedPreference = UserDefaults.standard.bool(forKey: notificationsStorageKey)
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        await MainActor.run {
            notificationsEnabled = storedPreference && settings.authorizationStatus == .authorized
        }
    }

    private func updateNotifications(enabled: Bool) {
        if enabled {
            Task {
                let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false

                await MainActor.run {
                    notificationsEnabled = granted
                    UserDefaults.standard.set(granted, forKey: notificationsStorageKey)
                }
            }
        } else {
            notificationsEnabled = false
            UserDefaults.standard.set(false, forKey: notificationsStorageKey)
        }
    }

    private func service() throws -> AuthServicing {
        if let authService { return authService }
        let createdService = try SupabaseAuthService()
        authService = createdService
        return createdService
    }
}

private struct ProfileAvatarView: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color(hex: 0xC2C3C5))
                    .overlay {
                        GeometryReader { proxy in
                            let size = proxy.size.width

                            ZStack {
                                Circle()
                                    .fill(Color(hex: 0x9F9F9F))
                                    .frame(width: size * 0.45, height: size * 0.45)
                                    .position(x: size * 0.5, y: size * 0.36)

                                Ellipse()
                                    .fill(Color(hex: 0x9F9F9F))
                                    .frame(width: size * 0.94, height: size * 0.61)
                                    .position(x: size * 0.5, y: size * 0.88)
                            }
                            .clipShape(Circle())
                        }
                    }
            }
        }
        .clipShape(Circle())
    }
}

private struct ProfileSettingsSection<Content: View>: View {
    let title: String
    let accentBlue: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)
                .padding(.leading, 22)
                .padding(.bottom, 10)

            Rectangle()
                .fill(accentBlue)
                .frame(height: 1)

            VStack(spacing: 0) {
                content
            }
        }
    }
}

private struct ProfileSettingsRow: View {
    let icon: String
    let title: String
    let accentBlue: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(accentBlue)
                    .frame(width: 64, alignment: .leading)

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
            }
            .padding(.leading, 22)
            .padding(.trailing, 22)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let accentBlue: Color
    let toggleBlue: Color

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(accentBlue)
                .frame(width: 64, alignment: .leading)

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(toggleBlue)
                .scaleEffect(0.88)
        }
        .padding(.leading, 22)
        .padding(.trailing, 16)
        .frame(height: 64)
    }
}

#Preview {
    UserProfileView(
        user: AppUser(id: UUID(), name: "Michael", email: "michael@example.com"),
        onUserUpdated: { _ in },
        onClose: {},
        onLogOut: {}
    )
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
