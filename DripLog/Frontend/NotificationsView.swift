import SwiftUI

struct NotificationsView: View {
    let user: AppUser
    let onBack: () -> Void

    @State private var notifications: [SocialNotification] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var notificationService: (any NotificationServicing)?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 44)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 28)
                            .padding(.top, 44)
                    } else if notifications.isEmpty {
                        Text("No notifications yet.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 44)
                    } else {
                        ForEach(NotificationSection.sections(for: notifications)) { section in
                            if !section.notifications.isEmpty {
                                Text(section.title)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 20)
                                    .padding(.top, section.topPadding)
                                    .padding(.bottom, 6)

                                VStack(spacing: 14) {
                                    ForEach(section.notifications) { notification in
                                        NotificationRow(
                                            notification: notification,
                                            onFollowBack: {
                                                Task { await followBack(notification) }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .background(Color.white)
        .task {
            await loadNotifications()
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Notifications")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                HStack {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.black)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 10)
            .frame(height: 58)

            Rectangle()
                .fill(Color(hex: 0x9BB3E1))
                .frame(height: 2)
        }
    }

    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            notifications = try await getService().fetchNotifications(for: user.id)
        } catch {
            errorMessage = "Could not load notifications right now."
        }
    }

    private func followBack(_ notification: SocialNotification) async {
        guard case .followed(let requestID, false) = notification.kind else { return }

        markFollowingBack(requestID: requestID)
        do {
            try await getService().followBack(requestID: requestID)
        } catch {
            markFollowingBack(requestID: requestID, isFollowingBack: false)
        }
    }

    private func markFollowingBack(requestID: UUID, isFollowingBack: Bool = true) {
        notifications = notifications.map { notification in
            guard case .followed(let existingID, _) = notification.kind, existingID == requestID else {
                return notification
            }
            return SocialNotification(
                id: notification.id,
                actorID: notification.actorID,
                actorName: notification.actorName,
                actorAvatarURL: notification.actorAvatarURL,
                createdAt: notification.createdAt,
                kind: .followed(requestID: requestID, isFollowingBack: isFollowingBack)
            )
        }
    }

    private func getService() throws -> any NotificationServicing {
        if let notificationService { return notificationService }
        let service = try SupabaseNotificationService()
        notificationService = service
        return service
    }
}

private struct NotificationRow: View {
    let notification: SocialNotification
    let onFollowBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            NotificationAvatar(url: notification.actorAvatarURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.black)
                    .lineLimit(2)

                Text(relativeTime)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.black)
            }

            Spacer(minLength: 8)

            trailingView
        }
        .frame(minHeight: 52)
    }

    @ViewBuilder
    private var trailingView: some View {
        switch notification.kind {
        case .likedOutfit(_, let imageURL):
            if let imageURL {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                }
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipped()
                .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 58, height: 58)
            }
        case .followed(_, let isFollowingBack):
            Button(action: onFollowBack) {
                Text(isFollowingBack ? "Following" : "Follow Back")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 103, height: 31)
                    .background(
                        isFollowingBack ? Color(hex: 0x9BB3E1) : Color.black,
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isFollowingBack)
        }
    }

    private var message: String {
        switch notification.kind {
        case .likedOutfit:
            "\(notification.actorName) liked your outfit!"
        case .followed:
            "\(notification.actorName) just started following you"
        }
    }

    private var relativeTime: String {
        let seconds = max(0, Int(Date().timeIntervalSince(notification.createdAt)))
        if seconds < 60 { return "\(max(seconds, 1))s ago" }

        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }

        let days = hours / 24
        return "\(days)d ago"
    }
}

private struct NotificationAvatar: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.black.opacity(0.14))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.35))
            }
    }
}

private struct NotificationSection: Identifiable {
    let id: String
    let title: String
    let notifications: [SocialNotification]
    let topPadding: CGFloat

    static func sections(for notifications: [SocialNotification]) -> [NotificationSection] {
        [
            NotificationSection(
                id: "today",
                title: "Today",
                notifications: notifications.filter { Calendar.current.isDateInToday($0.createdAt) },
                topPadding: 14
            ),
            NotificationSection(
                id: "yesterday",
                title: "Yesterday",
                notifications: notifications.filter { Calendar.current.isDateInYesterday($0.createdAt) },
                topPadding: 12
            ),
            NotificationSection(
                id: "last7",
                title: "Last 7 days",
                notifications: notifications.filter { $0.createdAt.isWithinDays(7) && !Calendar.current.isDateInToday($0.createdAt) && !Calendar.current.isDateInYesterday($0.createdAt) },
                topPadding: 12
            ),
            NotificationSection(
                id: "last30",
                title: "Last 30 days",
                notifications: notifications.filter { $0.createdAt.isWithinDays(30) && !$0.createdAt.isWithinDays(7) },
                topPadding: 12
            )
        ]
    }
}

private extension Date {
    func isWithinDays(_ days: Int) -> Bool {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return false
        }
        return self >= cutoff
    }
}
