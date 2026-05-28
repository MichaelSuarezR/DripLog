import Foundation
import Supabase

// MARK: - FeedPost

struct FeedPost: Identifiable {
    let id: UUID
    let authorID: UUID
    let authorName: String
    let authorAvatarURL: URL?
    let imageURL: URL
    let caption: String?
    let tags: [String]
    let createdAt: Date
    let followStatus: FeedFollowStatus
    let isLiked: Bool
    let isBookmarked: Bool
}

struct FeedPage {
    let posts: [FeedPost]
    let fetchedRowCount: Int
}

struct FeedStats {
    let followers: Int
    let following: Int
}

enum FeedFollowStatus {
    case ownPost
    case notFollowing
    case following

    var buttonTitle: String? {
        switch self {
        case .ownPost:
            nil
        case .notFollowing:
            "Follow"
        case .following:
            "Following"
        }
    }
}

enum FeedScope: CaseIterable {
    case recent
    case friendsOnly
    case saved

    var title: String {
        switch self {
        case .recent:
            "Recent"
        case .friendsOnly:
            "Friends Only"
        case .saved:
            "Saved"
        }
    }
}

// MARK: - FeedServicing

protocol FeedServicing {
    func fetchFeedPosts(scope: FeedScope, currentUserID: UUID, page: Int) async throws -> FeedPage
    func fetchStats(for userID: UUID) async throws -> FeedStats
    func follow(authorID: UUID, currentUserID: UUID) async throws
    func setLike(_ isLiked: Bool, outfitID: UUID, userID: UUID) async throws
    func setBookmark(_ isBookmarked: Bool, outfitID: UUID, userID: UUID) async throws
}

// MARK: - SupabaseFeedService

struct SupabaseFeedService: FeedServicing {
    private let client: SupabaseClient
    private let bucketName = "outfit-photos"
    private let pageSize = 5
    private let profilePhotosBucket = "profile-photos"

    init(client: SupabaseClient? = nil) throws {
        self.client = try client ?? SupabaseClientProvider.makeClient()
    }

    func fetchFeedPosts(scope: FeedScope, currentUserID: UUID, page: Int) async throws -> FeedPage {
        let from = page * pageSize
        let to = from + pageSize - 1

        let friendships = (try? await fetchFriendshipsInvolving(userID: currentUserID)) ?? []
        let followingIDs = Set(friendships.filter {
            $0.requesterID == currentUserID
        }.map(\.addresseeID))
        let followerIDs = Set(friendships.filter {
            $0.addresseeID == currentUserID
        }.map(\.requesterID))
        let mutualFriendIDs = followingIDs.intersection(followerIDs)
        let bookmarkedIDs = (try? await fetchBookmarkedOutfitIDs(for: currentUserID)) ?? []
        let likedIDs = (try? await fetchLikedOutfitIDs(for: currentUserID)) ?? []

        let rows: [FeedRow]
        switch scope {
        case .recent:
            rows = try await fetchAllRows(from: from, to: to)
        case .friendsOnly:
            guard !mutualFriendIDs.isEmpty else { return FeedPage(posts: [], fetchedRowCount: 0) }
            rows = try await fetchFriendRows(friendIDs: mutualFriendIDs, from: from, to: to)
        case .saved:
            guard !bookmarkedIDs.isEmpty else { return FeedPage(posts: [], fetchedRowCount: 0) }
            rows = try await client
                .from("outfits")
                .select("id,user_id,image_path,caption,categories,weather,occasion,colors,visibility,created_at")
                .in("id", values: Array(bookmarkedIDs))
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
        }
        let profiles = (try? await fetchProfiles(ids: Array(Set(rows.map(\.userID))))) ?? [:]

        let posts: [FeedPost] = try await withThrowingTaskGroup(of: FeedPost?.self) { group in
            for row in rows {
                group.addTask {
                    let profile = profiles[row.userID]
                    guard let signedURL = try? await self.client.storage
                        .from(self.bucketName)
                        .createSignedURL(path: row.imagePath, expiresIn: 3600) else {
                            return nil
                        }
                    let allTags = (row.categories + row.weather + row.occasion + row.colors)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    return FeedPost(
                        id: row.id,
                        authorID: row.userID,
                        authorName: profile?.displayName ?? "user",
                        authorAvatarURL: profile?.avatarURL,
                        imageURL: signedURL,
                        caption: row.caption,
                        tags: allTags,
                        createdAt: row.createdAt,
                        followStatus: followStatus(
                            authorID: row.userID,
                            currentUserID: currentUserID,
                            followingIDs: followingIDs
                        ),
                        isLiked: likedIDs.contains(row.id),
                        isBookmarked: bookmarkedIDs.contains(row.id)
                    )
                }
            }

            var results: [FeedPost] = []
            for try await post in group {
                if let post { results.append(post) }
            }
            return results.sorted { $0.createdAt > $1.createdAt }
        }

        return FeedPage(posts: posts, fetchedRowCount: rows.count)
    }

    func fetchStats(for userID: UUID) async throws -> FeedStats {
        let followingRows: [FriendshipRow] = try await client
            .from("friendships")
            .select("id,requester_id,addressee_id,status,created_at")
            .eq("requester_id", value: userID)
            .eq("status", value: "accepted")
            .execute()
            .value

        let followerRows: [FriendshipRow] = try await client
            .from("friendships")
            .select("id,requester_id,addressee_id,status,created_at")
            .eq("addressee_id", value: userID)
            .eq("status", value: "accepted")
            .execute()
            .value

        return FeedStats(followers: followerRows.count, following: followingRows.count)
    }

    func follow(authorID: UUID, currentUserID: UUID) async throws {
        guard authorID != currentUserID else { return }

        try await client
            .from("friendships")
            .insert(FriendshipInsert(
                requesterID: currentUserID,
                addresseeID: authorID,
                status: "accepted"
            ))
            .execute()
    }

    func setLike(_ isLiked: Bool, outfitID: UUID, userID: UUID) async throws {
        if isLiked {
            try await client
                .from("outfit_likes")
                .insert(OutfitReactionInsert(userID: userID, outfitID: outfitID))
                .execute()
        } else {
            try await client
                .from("outfit_likes")
                .delete()
                .eq("user_id", value: userID)
                .eq("outfit_id", value: outfitID)
                .execute()
        }
    }

    func setBookmark(_ isBookmarked: Bool, outfitID: UUID, userID: UUID) async throws {
        if isBookmarked {
            try await client
                .from("outfit_bookmarks")
                .insert(BookmarkInsert(userID: userID, outfitID: outfitID))
                .execute()
        } else {
            try await client
                .from("outfit_bookmarks")
                .delete()
                .eq("user_id", value: userID)
                .eq("outfit_id", value: outfitID)
                .execute()
        }
    }

    private func fetchFriendshipsInvolving(userID: UUID) async throws -> [FriendshipRow] {
        let rows: [FriendshipRow] = try await client
            .from("friendships")
            .select("id,requester_id,addressee_id,status,created_at")
            .or("requester_id.eq.\(userID.uuidString),addressee_id.eq.\(userID.uuidString)")
            .execute()
            .value

        return rows
    }

    private func fetchBookmarkedOutfitIDs(for userID: UUID) async throws -> Set<UUID> {
        let rows: [BookmarkRow] = try await client
            .from("outfit_bookmarks")
            .select("outfit_id")
            .eq("user_id", value: userID)
            .execute()
            .value

        return Set(rows.map(\.outfitID))
    }

    private func fetchLikedOutfitIDs(for userID: UUID) async throws -> Set<UUID> {
        let rows: [OutfitReactionRow] = try await client
            .from("outfit_likes")
            .select("outfit_id")
            .eq("user_id", value: userID)
            .execute()
            .value

        return Set(rows.map(\.outfitID))
    }

    private func followStatus(
        authorID: UUID,
        currentUserID: UUID,
        followingIDs: Set<UUID>
    ) -> FeedFollowStatus {
        if authorID == currentUserID { return .ownPost }
        if followingIDs.contains(authorID) { return .following }
        return .notFollowing
    }

    private func fetchAllRows(from: Int, to: Int) async throws -> [FeedRow] {
        do {
            return try await client
                .from("outfits")
                .select(feedSelectWithVisibility)
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
        } catch {
            return try await fetchLegacyAllRows(from: from, to: to)
        }
    }

    private func fetchFriendRows(friendIDs: Set<UUID>, from: Int, to: Int) async throws -> [FeedRow] {
        do {
            let rows: [FeedRow] = try await client
                .from("outfits")
                .select(feedSelectWithVisibility)
                .in("user_id", values: Array(friendIDs))
                .in("visibility", values: [OutfitVisibility.publicProfile.title, OutfitVisibility.friends.title])
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
            return rows.isEmpty ? try await fetchLegacyFriendRows(friendIDs: friendIDs, from: from, to: to) : rows
        } catch {
            return try await fetchLegacyFriendRows(friendIDs: friendIDs, from: from, to: to)
        }
    }

    private func fetchLegacyAllRows(from: Int, to: Int) async throws -> [FeedRow] {
        try await client
            .from("outfits")
            .select(feedSelectWithoutVisibility)
            .order("created_at", ascending: false)
            .range(from: from, to: to)
            .execute()
            .value
    }

    private func fetchLegacyFriendRows(friendIDs: Set<UUID>, from: Int, to: Int) async throws -> [FeedRow] {
        try await client
            .from("outfits")
            .select(feedSelectWithoutVisibility)
            .in("user_id", values: Array(friendIDs))
            .order("created_at", ascending: false)
            .range(from: from, to: to)
            .execute()
            .value
    }

    private func fetchProfiles(ids: [UUID]) async throws -> [UUID: FeedProfile] {
        guard !ids.isEmpty else { return [:] }

        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select("id,first_name,last_name,email,avatar_path")
            .in("id", values: ids)
            .execute()
            .value

        var profiles: [UUID: FeedProfile] = [:]
        for row in rows {
            let avatarURL: URL?
            if let avatarPath = row.avatarPath, !avatarPath.isEmpty {
                avatarURL = try? await client.storage
                    .from(profilePhotosBucket)
                    .createSignedURL(path: avatarPath, expiresIn: 3600)
            } else {
                avatarURL = nil
            }

            profiles[row.id] = FeedProfile(
                id: row.id,
                displayName: row.displayName,
                avatarURL: avatarURL
            )
        }
        return profiles
    }

    private var feedSelectWithVisibility: String {
        "id,user_id,image_path,caption,categories,weather,occasion,colors,visibility,created_at"
    }

    private var feedSelectWithoutVisibility: String {
        "id,user_id,image_path,caption,categories,weather,occasion,colors,created_at"
    }
}

// MARK: - Private row types

private struct FeedRow: Decodable {
    let id: UUID
    let userID: UUID
    let imagePath: String
    let caption: String?
    let categories: [String]
    let weather: [String]
    let occasion: [String]
    let colors: [String]
    let visibility: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case imagePath = "image_path"
        case caption
        case categories
        case weather
        case occasion
        case colors
        case visibility
        case createdAt = "created_at"
    }
}

private struct FeedProfile {
    let id: UUID
    let displayName: String
    let avatarURL: URL?
}

private struct ProfileRow: Decodable {
    let id: UUID
    let firstName: String?
    let lastName: String?
    let email: String
    let avatarPath: String?

    var displayName: String {
        let names = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let name = names.joined(separator: " ")
        return name.isEmpty ? email.components(separatedBy: "@").first ?? "user" : name
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case avatarPath = "avatar_path"
    }
}

private struct FriendshipRow: Decodable {
    let id: UUID
    let requesterID: UUID
    let addresseeID: UUID
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
        case createdAt = "created_at"
    }
}

private struct BookmarkRow: Decodable {
    let outfitID: UUID

    enum CodingKeys: String, CodingKey {
        case outfitID = "outfit_id"
    }
}

private struct BookmarkInsert: Encodable {
    let userID: UUID
    let outfitID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case outfitID = "outfit_id"
    }
}

private struct OutfitReactionRow: Decodable {
    let outfitID: UUID

    enum CodingKeys: String, CodingKey {
        case outfitID = "outfit_id"
    }
}

private struct OutfitReactionInsert: Encodable {
    let userID: UUID
    let outfitID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case outfitID = "outfit_id"
    }
}

private struct FriendshipInsert: Encodable {
    let requesterID: UUID
    let addresseeID: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
    }
}
