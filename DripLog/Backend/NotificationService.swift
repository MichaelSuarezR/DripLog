import Foundation
import Supabase

struct SocialNotification: Identifiable, Equatable {
    let id: String
    let actorID: UUID
    let actorName: String
    let actorAvatarURL: URL?
    let createdAt: Date
    let kind: SocialNotificationKind
}

enum SocialNotificationKind: Equatable {
    case likedOutfit(outfitID: UUID, outfitImageURL: URL?)
    case followed(requestID: UUID, isFollowingBack: Bool)
}

protocol NotificationServicing {
    func fetchNotifications(for userID: UUID) async throws -> [SocialNotification]
    func followBack(requestID: UUID) async throws
}

struct SupabaseNotificationService: NotificationServicing {
    private let client: SupabaseClient
    private let outfitPhotosBucket = "outfit-photos"
    private let profilePhotosBucket = "profile-photos"

    init(client: SupabaseClient? = nil) throws {
        self.client = try client ?? SupabaseClientProvider.makeClient()
    }

    func fetchNotifications(for userID: UUID) async throws -> [SocialNotification] {
        async let likedOutfits = fetchLikeNotifications(for: userID)
        async let follows = fetchFollowNotifications(for: userID)

        return try await (likedOutfits + follows)
            .sorted { $0.createdAt > $1.createdAt }
            .filter { $0.actorID != userID }
    }

    func followBack(requestID: UUID) async throws {
        let rows: [NotificationFriendshipRow] = try await client
            .from("friendships")
            .select("id,requester_id,addressee_id,status,created_at")
            .eq("id", value: requestID)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else { return }

        try await client
            .from("friendships")
            .insert(NotificationFriendshipInsert(
                requesterID: row.addresseeID,
                addresseeID: row.requesterID,
                status: "accepted"
            ))
            .execute()
    }

    private func fetchLikeNotifications(for userID: UUID) async throws -> [SocialNotification] {
        let outfitRows: [NotificationOutfitRow] = try await client
            .from("outfits")
            .select("id,user_id,image_path,created_at")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .limit(80)
            .execute()
            .value

        let outfitIDs = outfitRows.map(\.id)
        guard !outfitIDs.isEmpty else { return [] }

        let outfitsByID = Dictionary(uniqueKeysWithValues: outfitRows.map { ($0.id, $0) })
        let likeRows: [NotificationLikeRow] = try await client
            .from("outfit_likes")
            .select("user_id,outfit_id,created_at")
            .in("outfit_id", values: outfitIDs)
            .order("created_at", ascending: false)
            .limit(60)
            .execute()
            .value

        let likes = likeRows.filter { $0.userID != userID }
        let profiles = try await fetchProfiles(ids: Array(Set(likes.map(\.userID))))
        var imageURLCache: [UUID: URL] = [:]
        var notifications: [SocialNotification] = []

        for row in likes {
            guard let profile = profiles[row.userID], let outfit = outfitsByID[row.outfitID] else { continue }
            let outfitURL: URL?
            if let cached = imageURLCache[row.outfitID] {
                outfitURL = cached
            } else {
                outfitURL = try? await client.storage
                    .from(outfitPhotosBucket)
                    .createSignedURL(
                        path: outfit.imagePath,
                        expiresIn: 3600,
                        transform: TransformOptions(width: 140, quality: 70)
                    )
                imageURLCache[row.outfitID] = outfitURL
            }

            notifications.append(
                SocialNotification(
                    id: "like-\(row.userID.uuidString)-\(row.outfitID.uuidString)-\(row.createdAt.timeIntervalSince1970)",
                    actorID: row.userID,
                    actorName: profile.displayName,
                    actorAvatarURL: profile.avatarURL,
                    createdAt: row.createdAt,
                    kind: .likedOutfit(outfitID: row.outfitID, outfitImageURL: outfitURL)
                )
            )
        }

        return notifications
    }

    private func fetchFollowNotifications(for userID: UUID) async throws -> [SocialNotification] {
        let allRows: [NotificationFriendshipRow] = try await client
            .from("friendships")
            .select("id,requester_id,addressee_id,status,created_at")
            .or("requester_id.eq.\(userID.uuidString),addressee_id.eq.\(userID.uuidString)")
            .eq("status", value: "accepted")
            .execute()
            .value

        let followingIDs = Set(allRows.filter { $0.requesterID == userID }.map(\.addresseeID))
        let rows: [NotificationFriendshipRow] = try await client
            .from("friendships")
            .select("id,requester_id,addressee_id,status,created_at")
            .eq("addressee_id", value: userID)
            .eq("status", value: "accepted")
            .order("created_at", ascending: false)
            .limit(60)
            .execute()
            .value

        let profiles = try await fetchProfiles(ids: Array(Set(rows.map(\.requesterID))))

        return rows.compactMap { row in
            guard let profile = profiles[row.requesterID] else { return nil }
            return SocialNotification(
                id: "follow-\(row.id.uuidString)",
                actorID: row.requesterID,
                actorName: profile.displayName,
                actorAvatarURL: profile.avatarURL,
                createdAt: row.createdAt,
                kind: .followed(requestID: row.id, isFollowingBack: followingIDs.contains(row.requesterID))
            )
        }
    }

    private func fetchProfiles(ids: [UUID]) async throws -> [UUID: NotificationProfile] {
        guard !ids.isEmpty else { return [:] }

        let rows: [NotificationProfileRow] = try await client
            .from("profiles")
            .select("id,first_name,last_name,email,avatar_path")
            .in("id", values: ids)
            .execute()
            .value

        var profiles: [UUID: NotificationProfile] = [:]
        for row in rows {
            let avatarURL: URL?
            if let avatarPath = row.avatarPath, !avatarPath.isEmpty {
                avatarURL = try? await client.storage
                    .from(profilePhotosBucket)
                    .createSignedURL(path: avatarPath, expiresIn: 3600)
            } else {
                avatarURL = nil
            }

            profiles[row.id] = NotificationProfile(displayName: row.displayName, avatarURL: avatarURL)
        }
        return profiles
    }
}

private struct NotificationProfile {
    let displayName: String
    let avatarURL: URL?
}

private struct NotificationProfileRow: Decodable {
    let id: UUID
    let firstName: String?
    let lastName: String?
    let email: String
    let avatarPath: String?

    var displayName: String {
        let fullName = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return fullName.isEmpty ? email.components(separatedBy: "@").first ?? "user" : fullName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case avatarPath = "avatar_path"
    }
}

private struct NotificationOutfitRow: Decodable {
    let id: UUID
    let userID: UUID
    let imagePath: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case imagePath = "image_path"
        case createdAt = "created_at"
    }
}

private struct NotificationLikeRow: Decodable {
    let userID: UUID
    let outfitID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case outfitID = "outfit_id"
        case createdAt = "created_at"
    }
}

private struct NotificationFriendshipRow: Decodable {
    let id: UUID
    let requesterID: UUID
    let addresseeID: UUID
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
        case createdAt = "created_at"
    }
}

private struct NotificationFriendshipInsert: Encodable {
    let requesterID: UUID
    let addresseeID: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
    }
}
