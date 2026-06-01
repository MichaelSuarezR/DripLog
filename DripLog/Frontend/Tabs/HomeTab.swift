import SwiftUI

struct HomeTab: View {
    let user: AppUser
    @ObservedObject var feedStore: FeedStore
    let profilePhotoURL: URL?
    let onProfileTapped: () -> Void

    @EnvironmentObject private var tutorialManager: TutorialManager

    @State private var selectedAuthor: FriendProfile?
    @State private var isShowingNotifications = false
    @State private var friendsTabToShow: FriendsTab?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    socialHeader

                    Text("Your Feed")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.top, 14)

                    feedScopeSelector
                        .padding(.top, 10)

                    if feedStore.posts.isEmpty && feedStore.isLoading {
                        ProgressView()
                            .padding(.top, 40)

                    } else if let errorMessage = feedStore.errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                            .padding(.horizontal, 24)

                    } else if feedStore.posts.isEmpty {
                        Text(emptyFeedMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                            .padding(.horizontal, 24)

                    } else {
                        ForEach(feedStore.posts) { post in
                            FeedPostCard(
                                post: post,
                                onAuthorTap: {
                                    openAuthor(post)
                                },
                                onFollow: {
                                    Task { await feedStore.follow(post.authorID) }
                                },
                                onLikeToggle: {
                                    Task { await feedStore.toggleLike(for: post) }
                                },
                                onBookmarkToggle: {
                                    Task { await feedStore.toggleBookmark(for: post) }
                                }
                            )
                            .padding(.top, 14)
                        }

                        if feedStore.hasMore {
                            ProgressView()
                                .padding(.vertical, 16)
                                .onAppear {
                                    Task {
                                        await feedStore.loadNextPageIfNeeded()
                                    }
                                }
                                .onChange(of: feedStore.isLoading) { _, loading in
                                    guard !loading, feedStore.hasMore else { return }
                                    Task {
                                        await feedStore.loadNextPageIfNeeded()
                                    }
                                }

                        } else if !feedStore.posts.isEmpty {
                            Text("you're all caught up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 20)
                .padding(.bottom, 96)
            }
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
            .tutorialAnchor(step: .feed)
            .task {
                await feedStore.loadInitialIfNeeded()
            }
            .refreshable {
                await feedStore.refreshCurrentScope()
            }
            .fullScreenCover(item: $selectedAuthor) { profile in
                FriendProfileDetailView(
                    profile: profile,
                    isSent: feedStore.isRequestSentOrFollowing(profile.id),
                    onBack: {
                        selectedAuthor = nil
                    },
                    onFollow: {
                        await feedStore.follow(profile.id)
                    }
                )
            }
            .fullScreenCover(isPresented: $isShowingNotifications) {
                NotificationsView(
                    user: user,
                    onBack: {
                        isShowingNotifications = false
                    }
                )
            }
            .fullScreenCover(item: $friendsTabToShow) { tab in
                FriendsView(user: user, initialTab: tab) {
                    friendsTabToShow = nil
                }
            }
        }
        .overlay {
            TutorialOverlay(
                step: .feed,
                title: "Your feed",
                message: "View your posts and your friends' posts in your feed! Interact with and save outfits you like.",
                anchorFrame: tutorialManager.anchorFrames[.feed]
            )
        }
    }

    private var socialHeader: some View {
        ZStack(alignment: .top) {
            HStack {
                Button {
                    isShowingNotifications = true
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onProfileTapped) {
                    Image(systemName: "pencil")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open profile settings")
            }
            .padding(.top, 0)

            VStack(spacing: 8) {
                FeedProfileAvatar(url: profilePhotoURL)
                    .accessibilityLabel("Profile photo")

                Text("Welcome, \(displayName)!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                HStack(spacing: 42) {
                    statButton(value: feedStore.stats.followers, label: "Followers") {
                        friendsTabToShow = .friendRequests
                    }
                    statButton(value: feedStore.stats.following, label: "Following") {
                        friendsTabToShow = .friends
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statBlock(value: Int, label: String) -> some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.black)

            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
        }
    }

    private func statButton(value: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            statBlock(value: value, label: label)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(label)")
    }

    private var feedScopeSelector: some View {
        HStack(spacing: 12) {
            ForEach(FeedScope.allCases, id: \.self) { scope in
                Button {
                    feedStore.selectScope(scope)
                } label: {
                    Text(scope.title)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 25)
                        .background(
                            feedStore.selectedScope == scope
                            ? Color(hex: 0xE4432D)
                            : Color(hex: 0x9BB3E1),
                            in: RoundedRectangle(
                                cornerRadius: 11,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
        }
    }

    private func openAuthor(_ post: FeedPost) {
        if post.authorID == user.id {
            onProfileTapped()
            return
        }

        selectedAuthor = FriendProfile(
            id: post.authorID,
            name: post.authorName,
            email: "",
            avatarURL: post.authorAvatarURL
        )
    }

    private var displayName: String {
        let trimmedName = user.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let firstName = trimmedName
            .split(separator: " ")
            .first
            .map(String.init) ?? ""

        return firstName.isEmpty ? "Matthew" : firstName
    }

    private var emptyFeedMessage: String {
        switch feedStore.selectedScope {
        case .recent:
            return "No public posts yet."

        case .friendsOnly:
            return "No friends-only posts yet."

        case .saved:
            return "No saved posts yet."
        }
    }
}

// MARK: - FeedPostCard

struct FeedPostCard: View {
    let post: FeedPost
    let onAuthorTap: () -> Void
    let onFollow: () -> Void
    let onLikeToggle: () -> Void
    let onBookmarkToggle: () -> Void

    @State private var imageScale: CGFloat = 1
    @State private var imageZoomAnchor: UnitPoint = .center

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onAuthorTap) {
                    HStack(spacing: 8) {
                        FeedSmallAvatar(url: post.authorAvatarURL)

                        Text(post.authorName.lowercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                if let title = post.followStatus.buttonTitle {
                    HStack(spacing: 0) {
                        Image("followbuddy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 76, height: 52)
                            .offset(x: 30)
                            .allowsHitTesting(false)

                        Button(action: onFollow) {
                            Text(title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 103, height: 29)
                                .background(
                                    followButtonColor,
                                    in: RoundedRectangle(
                                        cornerRadius: 5,
                                        style: .continuous
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(post.followStatus != .notFollowing)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        CachedAsyncImage(url: post.imageURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(imageScale, anchor: imageZoomAnchor)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    }
                }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
            .clipped()
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        imageZoomAnchor = value.startAnchor
                        imageScale = min(max(value.magnification, 1), 4)
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                            imageScale = 1
                            imageZoomAnchor = .center
                        }
                    }
            )
            .padding(.horizontal, 4)

            HStack(alignment: .top) {
                Text(captionText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .allowsHitTesting(false)

                Spacer()

                Button(action: onLikeToggle) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(
                            post.isLiked
                            ? Color(hex: 0xE4432D)
                            : .black
                        )
                }
                .buttonStyle(.plain)

                Button(action: onBookmarkToggle) {
                    Image(systemName: post.isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 28, weight: .regular))
            .padding(.horizontal, 13)
            .padding(.top, 6)

            Text(Self.dateFormatter.string(from: post.createdAt).lowercased())
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(hex: 0x9BB3E1))
                .padding(.horizontal, 13)
                .padding(.top, 1)
                .allowsHitTesting(false)

            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.tags.prefix(4), id: \.self) { tag in
                            Text(tag.capitalized)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 13)
                                .frame(height: 22)
                                .background(
                                    Color(hex: 0x9BB3E1),
                                    in: RoundedRectangle(
                                        cornerRadius: 6,
                                        style: .continuous
                                    )
                                )
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 13)
                }
                .padding(.top, 9)
                .allowsHitTesting(false)
            }
        }
        .padding(.bottom, 4)
    }

    private var captionText: String {
        let trimmed = post.caption?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmed.isEmpty else {
            return "just posted a fit."
        }

        if let data = trimmed.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data),
           !decoded.isEmpty {
            return decoded.joined(separator: ", ")
        }

        return trimmed
    }

    private var followButtonColor: Color {
        post.followStatus == .notFollowing
        ? .black
        : Color(hex: 0x9BB3E1)
    }
}

// MARK: - FeedProfileAvatar

private struct FeedProfileAvatar: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url, showsLoadingIndicator: false) { image in
                    image
                        .resizable()
                        .scaledToFill()
                }

            } else {
                placeholder
            }
        }
        .frame(width: 86, height: 86)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.black.opacity(0.12))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.38))
            }
    }
}

// MARK: - FeedFilterChip

struct FeedFilterChip: View {
    let title: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 25)
                .background(
                    isActive
                    ? Color(hex: 0xE4432D)
                    : Color(hex: 0x9BB3E1),
                    in: RoundedRectangle(
                        cornerRadius: 11,
                        style: .continuous
                    )
                )
                .frame(height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FeedSmallAvatar

private struct FeedSmallAvatar: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url, showsLoadingIndicator: false) { image in
                    image
                        .resizable()
                        .scaledToFill()
                }

            } else {
                placeholder
            }
        }
        .frame(width: 27, height: 27)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.black.opacity(0.14))
    }
}
