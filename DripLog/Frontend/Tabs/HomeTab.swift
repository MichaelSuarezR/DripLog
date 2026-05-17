import SwiftUI

struct HomeTab: View {
    let user: AppUser
    let onProfileTapped: () -> Void

    @State private var posts: [FeedPost] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var errorMessage: String?
    @State private var feedService: (any FeedServicing)?
    @State private var profilePhotoURL: URL?
    @State private var authService: AuthServicing?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Button(action: onProfileTapped) {
                        FeedProfileAvatar(url: profilePhotoURL)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open profile")

                    Text("welcome, \(user.name.isEmpty ? "matthew" : user.name.lowercased())!")
                        .font(.title3.weight(.semibold))

                    Text("my friends")
                        .font(.headline)

                    HStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(Color.black.opacity(0.12))
                                .frame(width: 34, height: 34)
                        }
                    }

                    Text("your feed")
                        .font(.headline)
                        .padding(.top, 4)

                    HStack(spacing: 12) {
                        FeedFilterChip(title: "recent", isActive: true)
                        FeedFilterChip(title: "friends only")
                        FeedFilterChip(title: "saved")
                    }
                    .padding(.bottom, 2)

                    if posts.isEmpty && isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                    } else {
                        ForEach(posts) { post in
                            FeedPostCard(post: post)
                        }

                        if hasMore {
                            ProgressView()
                                .padding(.vertical, 16)
                                .onAppear {
                                    Task { await loadNextPage() }
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
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadNextPage() }
        }
        .onAppear {
            Task {
                await loadProfilePhoto()
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

    private func loadNextPage() async {
        guard !isLoading && hasMore else { return }
        isLoading = true
        do {
            let service = try getService()
            let newPosts = try await service.fetchFeedPosts(page: currentPage)
            posts.append(contentsOf: newPosts)
            currentPage += 1
            if newPosts.count < 5 { hasMore = false }
        } catch {
            errorMessage = "Could not load feed right now."
            hasMore = false
        }
        isLoading = false
    }

    private func getService() throws -> any FeedServicing {
        if let feedService { return feedService }
        let service = try SupabaseFeedService()
        feedService = service
        return service
    }
}

// MARK: - FeedPostCard

struct FeedPostCard: View {
    let post: FeedPost

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 33, height: 33)
                Text(post.authorName.lowercased())
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("follow")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 120, height: 33)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            CachedAsyncImage(url: post.imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 373)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipped()

            HStack {
                Text("OOTD")
                    .font(.headline.weight(.semibold))
                Spacer()
                Image(systemName: "message")
                Image(systemName: "heart")
                Image(systemName: "bookmark")
            }
            .font(.title3)

            Text(Self.dateFormatter.string(from: post.createdAt).lowercased())
                .font(.caption)
                .foregroundStyle(.secondary)

            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.tags.prefix(4), id: \.self) { tag in
                            Text(tag.lowercased())
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(.bottom, 10)
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

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 29)
            .background(
                isActive ? Color.black.opacity(0.25) : Color.black.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 14.5, style: .continuous)
            )
    }
}
