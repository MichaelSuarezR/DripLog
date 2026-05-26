import SwiftUI

struct HomeTab: View {
    let user: AppUser
    let onProfileTapped: () -> Void

    @State private var selectedScope: FeedScope = .recent
    @State private var posts: [FeedPost] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var errorMessage: String?
    @State private var loadToken = UUID()
    @State private var stats = FeedStats(followers: 0, following: 0)
    @State private var feedService: (any FeedServicing)?
    @State private var profilePhotoURL: URL?
    @State private var authService: AuthServicing?
    @State private var selectedAuthor: FriendProfile?
    @State private var isShowingNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    socialHeader

                    Text("Your Feed")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.top, 14)

                    feedScopeSelector
                        .padding(.top, 10)

                    if posts.isEmpty && isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                            .padding(.horizontal, 24)
                    } else if posts.isEmpty {
                        Text(emptyFeedMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                            .padding(.horizontal, 24)
                    } else {
                        ForEach(posts) { post in
                            FeedPostCard(
                                post: post,
                                onAuthorTap: {
                                    openAuthor(post)
                                },
                                onFollow: {
                                    Task { await follow(post.authorID) }
                                },
                                onLikeToggle: {
                                    Task { await toggleLike(for: post) }
                                },
                                onBookmarkToggle: {
                                    Task { await toggleBookmark(for: post) }
                                }
                            )
                            .padding(.top, 14)
                        }

                        if hasMore {
                            ProgressView()
                                .padding(.vertical, 16)
                                .onAppear {
                                    Task { await loadNextPage(for: loadToken) }
                                }
                        } else if !posts.isEmpty {
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
            .task {
                await loadProfilePhoto()
                await loadStats()
                await loadNextPage(for: loadToken)
            }
            .fullScreenCover(item: $selectedAuthor) { profile in
                FriendProfileDetailView(
                    profile: profile,
                    isSent: isRequestSentOrFollowing(profile.id),
                    onBack: {
                        selectedAuthor = nil
                    },
                    onFollow: {
                        await follow(profile.id)
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
        }
        .onAppear {
            Task {
                await loadProfilePhoto()
            }
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

                Button {} label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 0)

            VStack(spacing: 8) {
                Button(action: onProfileTapped) {
                    FeedProfileAvatar(url: profilePhotoURL)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open profile")

                Text("Welcome, \(displayName)!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                HStack(spacing: 42) {
                    statBlock(value: stats.followers, label: "Followers")
                    statBlock(value: stats.following, label: "Following")
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

    private var feedScopeSelector: some View {
        HStack(spacing: 12) {
            ForEach(FeedScope.allCases, id: \.self) { scope in
                Button {
                    selectScope(scope)
                } label: {
                    Text(scope.title)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 25)
                        .background(
                            selectedScope == scope ? Color(hex: 0xE4432D) : Color(hex: 0x9BB3E1),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
        }
    }

    private func loadProfilePhoto() async {
        do {
            profilePhotoURL = try await service().fetchProfilePhotoURL(for: user.id)
        } catch {
            profilePhotoURL = nil
        }
    }

    private func service() throws -> AuthServicing {
        if let authService { return authService }
        let createdService = try SupabaseAuthService()
        authService = createdService
        return createdService
    }

    private func loadStats() async {
        do {
            stats = try await getService().fetchStats(for: user.id)
        } catch {
            stats = FeedStats(followers: 0, following: 0)
        }
    }

    private func selectScope(_ scope: FeedScope) {
        guard selectedScope != scope else { return }
        selectedScope = scope
        loadToken = UUID()
        let token = loadToken
        resetFeedState()
        Task { await loadNextPage(for: token) }
    }

    private func resetFeedState() {
        posts = []
        currentPage = 0
        hasMore = true
        errorMessage = nil
        isLoading = false
    }

    private func loadNextPage(for token: UUID? = nil) async {
        let token = token ?? loadToken
        guard token == loadToken && !isLoading && hasMore else { return }
        isLoading = true
        defer {
            if token == loadToken {
                isLoading = false
            }
        }

        do {
            let service = try getService()
            let newPosts = try await service.fetchFeedPosts(
                scope: selectedScope,
                currentUserID: user.id,
                page: currentPage
            )
            guard token == loadToken else { return }
            posts.append(contentsOf: newPosts)
            currentPage += 1
            if newPosts.count < 5 { hasMore = false }
        } catch {
            guard token == loadToken else { return }
            errorMessage = "Could not load feed right now: \(error.localizedDescription)"
            hasMore = false
        }
    }

    private func toggleBookmark(for post: FeedPost) async {
        let newValue = !post.isBookmarked
        setBookmarkState(newValue, for: post.id)
        if selectedScope == .saved && !newValue {
            posts.removeAll { $0.id == post.id }
        }

        do {
            try await getService().setBookmark(newValue, outfitID: post.id, userID: user.id)
        } catch {
            if selectedScope != .saved {
                setBookmarkState(post.isBookmarked, for: post.id)
            }
        }
    }

    private func toggleLike(for post: FeedPost) async {
        let newValue = !post.isLiked
        setLikeState(newValue, for: post.id)

        do {
            try await getService().setLike(newValue, outfitID: post.id, userID: user.id)
        } catch {
            setLikeState(post.isLiked, for: post.id)
        }
    }

    private func follow(_ authorID: UUID) async {
        do {
            try await getService().follow(authorID: authorID, currentUserID: user.id)
            posts = posts.map { existing in
                guard existing.authorID == authorID, existing.followStatus == .notFollowing else { return existing }
                return FeedPost(
                    id: existing.id,
                    authorID: existing.authorID,
                    authorName: existing.authorName,
                    authorAvatarURL: existing.authorAvatarURL,
                    imageURL: existing.imageURL,
                    caption: existing.caption,
                    tags: existing.tags,
                    createdAt: existing.createdAt,
                    followStatus: .following,
                    isLiked: existing.isLiked,
                    isBookmarked: existing.isBookmarked
                )
            }
        } catch {
            posts = posts.map { existing in
                guard existing.authorID == authorID, existing.followStatus == .following else { return existing }
                return replacing(existing, followStatus: .notFollowing)
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

    private func isRequestSentOrFollowing(_ authorID: UUID) -> Bool {
        posts.first(where: { $0.authorID == authorID })?.followStatus != .notFollowing
    }

    private func setLikeState(_ isLiked: Bool, for outfitID: UUID) {
        posts = posts.map { existing in
            guard existing.id == outfitID else { return existing }
            return replacing(existing, isLiked: isLiked)
        }
    }

    private func setBookmarkState(_ isBookmarked: Bool, for outfitID: UUID) {
        posts = posts.map { existing in
            guard existing.id == outfitID else { return existing }
            return replacing(existing, isBookmarked: isBookmarked)
        }
    }

    private func replacing(
        _ post: FeedPost,
        followStatus: FeedFollowStatus? = nil,
        isLiked: Bool? = nil,
        isBookmarked: Bool? = nil
    ) -> FeedPost {
        FeedPost(
            id: post.id,
            authorID: post.authorID,
            authorName: post.authorName,
            authorAvatarURL: post.authorAvatarURL,
            imageURL: post.imageURL,
            caption: post.caption,
            tags: post.tags,
            createdAt: post.createdAt,
            followStatus: followStatus ?? post.followStatus,
            isLiked: isLiked ?? post.isLiked,
            isBookmarked: isBookmarked ?? post.isBookmarked
        )
    }

    private func getService() throws -> any FeedServicing {
        if let feedService { return feedService }
        let service = try SupabaseFeedService()
        feedService = service
        return service
    }

    private var displayName: String {
        let trimmedName = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstName = trimmedName.split(separator: " ").first.map(String.init) ?? ""
        return firstName.isEmpty ? "Matthew" : firstName
    }

    private var emptyFeedMessage: String {
        switch selectedScope {
        case .recent:
            "No public posts yet."
        case .friendsOnly:
            "No friends-only posts yet."
        case .saved:
            "No saved posts yet."
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
                    Button(action: onFollow) {
                        Text(title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 103, height: 29)
                            .background(followButtonColor, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(post.followStatus != .notFollowing)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            CachedAsyncImage(url: post.imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 352)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipped()
            .allowsHitTesting(false)
            .padding(.horizontal, 4)

            HStack(alignment: .top) {
                Text("OOTD")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.black)
                    .allowsHitTesting(false)
                Spacer()

                Button(action: onLikeToggle) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(post.isLiked ? Color(hex: 0xE4432D) : .black)
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

            Text(captionText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.black)
                .padding(.horizontal, 13)
                .padding(.top, 6)
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
                                .background(Color(hex: 0x9BB3E1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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
        let trimmed = post.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "just posted a fit." }
        if let data = trimmed.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data),
           !decoded.isEmpty {
            return decoded.joined(separator: ", ")
        }
        return trimmed
    }

    private var followButtonColor: Color {
        post.followStatus == .notFollowing ? .black : Color(hex: 0x9BB3E1)
    }
}

// MARK: - FeedFilterChip

private struct FeedProfileAvatar: View {
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
        .frame(width: 50, height: 50)
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
                    isActive ? Color(hex: 0xE4432D) : Color(hex: 0x9BB3E1),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .frame(height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct FeedSmallAvatar: View {
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
        .frame(width: 27, height: 27)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.black.opacity(0.14))
    }
}
