import Foundation
import Combine

@MainActor
final class FeedStore: ObservableObject {
    @Published var selectedScope: FeedScope = .recent
    @Published private var scopeStates: [FeedScope: FeedScopeState] = Dictionary(
        uniqueKeysWithValues: FeedScope.allCases.map { ($0, FeedScopeState()) }
    )
    @Published private(set) var stats = FeedStats(followers: 0, following: 0)

    private let userID: UUID
    private let pageSize = 5
    private var service: (any FeedServicing)?
    private var statsDidLoad = false
    private var loadTokens: [FeedScope: UUID] = Dictionary(
        uniqueKeysWithValues: FeedScope.allCases.map { ($0, UUID()) }
    )

    init(userID: UUID) {
        self.userID = userID
    }

    var posts: [FeedPost] {
        currentState(for: selectedScope).posts
    }

    var isLoading: Bool {
        currentState(for: selectedScope).isLoading
    }

    var hasMore: Bool {
        currentState(for: selectedScope).hasMore
    }

    var errorMessage: String? {
        currentState(for: selectedScope).errorMessage
    }

    func loadInitialIfNeeded() async {
        async let statsLoad: Void = loadStatsIfNeeded()
        async let feedLoad: Void = loadNextPageIfNeeded()
        _ = await (statsLoad, feedLoad)
    }

    func loadStatsIfNeeded(force: Bool = false) async {
        guard force || !statsDidLoad else { return }

        do {
            stats = try await getService().fetchStats(for: userID)
            statsDidLoad = true
        } catch {
            stats = FeedStats(followers: 0, following: 0)
        }
    }

    func selectScope(_ scope: FeedScope) {
        guard selectedScope != scope else { return }
        selectedScope = scope

        Task {
            await loadNextPageIfNeeded()
        }
    }

    func refreshCurrentScope() async {
        let scope = selectedScope
        loadTokens[scope] = UUID()
        scopeStates[scope] = FeedScopeState()
        await loadNextPage(scope: scope, token: loadTokens[scope] ?? UUID())
    }

    func invalidateAllScopes() {
        for scope in FeedScope.allCases {
            loadTokens[scope] = UUID()
            scopeStates[scope] = FeedScopeState()
        }
    }

    func loadNextPageIfNeeded() async {
        let scope = selectedScope
        await loadNextPage(scope: scope, token: loadTokens[scope] ?? UUID())
    }

    func toggleBookmark(for post: FeedPost) async {
        let newValue = !post.isBookmarked
        setBookmarkState(newValue, for: post.id)

        if !newValue {
            removePost(post.id, from: .saved)
        }

        do {
            try await getService().setBookmark(
                newValue,
                outfitID: post.id,
                userID: userID
            )
        } catch {
            if selectedScope != .saved {
                setBookmarkState(post.isBookmarked, for: post.id)
            }
        }
    }

    func toggleLike(for post: FeedPost) async {
        let newValue = !post.isLiked
        setLikeState(newValue, for: post.id)

        do {
            try await getService().setLike(
                newValue,
                outfitID: post.id,
                userID: userID
            )
        } catch {
            setLikeState(post.isLiked, for: post.id)
        }
    }

    func follow(_ authorID: UUID) async {
        setFollowStatus(.following, for: authorID, whenCurrentStatusIs: .notFollowing)

        do {
            try await getService().follow(
                authorID: authorID,
                currentUserID: userID
            )
            stats = FeedStats(
                followers: stats.followers,
                following: stats.following + 1
            )
        } catch {
            setFollowStatus(.notFollowing, for: authorID, whenCurrentStatusIs: .following)
        }
    }

    func isRequestSentOrFollowing(_ authorID: UUID) -> Bool {
        scopeStates.values
            .flatMap(\.posts)
            .first(where: { $0.authorID == authorID })?
            .followStatus != .notFollowing
    }

    private func loadNextPage(scope: FeedScope, token: UUID) async {
        var state = currentState(for: scope)

        guard token == loadTokens[scope],
              !state.isLoading,
              state.hasMore else {
            return
        }

        state.isLoading = true
        state.didStart = true
        scopeStates[scope] = state

        do {
            let page = try await getService().fetchFeedPosts(
                scope: scope,
                currentUserID: userID,
                page: state.currentPage
            )

            guard token == loadTokens[scope] else { return }

            state = currentState(for: scope)
            state.posts.append(contentsOf: page.posts)
            state.currentPage += 1
            state.isLoading = false
            state.errorMessage = nil

            if page.fetchedRowCount < pageSize {
                state.hasMore = false
            }

            scopeStates[scope] = state

            Task {
                await ImageCache.shared.prefetch(urls: page.posts.map(\.imageURL))
                await ImageCache.shared.prefetchAndPin(urls: page.posts.compactMap(\.authorAvatarURL))
            }
        } catch {
            guard token == loadTokens[scope] else { return }

            state = currentState(for: scope)
            state.errorMessage = "Could not load feed right now: \(error.localizedDescription)"
            state.hasMore = false
            state.isLoading = false
            scopeStates[scope] = state
        }
    }

    private func currentState(for scope: FeedScope) -> FeedScopeState {
        scopeStates[scope] ?? FeedScopeState()
    }

    private func updatePosts(_ transform: (FeedPost) -> FeedPost?) {
        for scope in FeedScope.allCases {
            var state = currentState(for: scope)
            state.posts = state.posts.compactMap(transform)
            scopeStates[scope] = state
        }
    }

    private func removePost(_ id: UUID, from scope: FeedScope) {
        var state = currentState(for: scope)
        state.posts.removeAll { $0.id == id }
        scopeStates[scope] = state
    }

    private func setLikeState(_ isLiked: Bool, for outfitID: UUID) {
        updatePosts { post in
            guard post.id == outfitID else { return post }
            return replacing(post, isLiked: isLiked)
        }
    }

    private func setBookmarkState(_ isBookmarked: Bool, for outfitID: UUID) {
        updatePosts { post in
            guard post.id == outfitID else { return post }
            return replacing(post, isBookmarked: isBookmarked)
        }
    }

    private func setFollowStatus(
        _ followStatus: FeedFollowStatus,
        for authorID: UUID,
        whenCurrentStatusIs currentStatus: FeedFollowStatus
    ) {
        updatePosts { post in
            guard post.authorID == authorID,
                  post.followStatus == currentStatus else {
                return post
            }

            return replacing(post, followStatus: followStatus)
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
        if let service {
            return service
        }

        let createdService = try SupabaseFeedService()
        service = createdService
        return createdService
    }
}

private struct FeedScopeState {
    var posts: [FeedPost] = []
    var currentPage = 0
    var isLoading = false
    var hasMore = true
    var errorMessage: String?
    var didStart = false
}
