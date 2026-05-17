import Foundation
import Supabase

struct FriendProfile: Identifiable, Equatable {
    let id: UUID
    let name: String
    let email: String
    let avatarURL: URL?
}

struct FriendRequest: Identifiable, Equatable {
    let id: UUID
    let user: FriendProfile
}

struct FriendSearchResult: Identifiable, Equatable {
    let profile: FriendProfile
    let hasSentRequest: Bool

    var id: UUID { profile.id }
}

protocol FriendServicing {
    func fetchFriends(for userID: UUID) async throws -> [FriendProfile]
    func fetchIncomingRequests(for userID: UUID) async throws -> [FriendRequest]
    func searchUsers(matching query: String, currentUserID: UUID) async throws -> [FriendSearchResult]
    func sendFriendRequest(from requesterID: UUID, to addresseeID: UUID) async throws
    func acceptFriendRequest(_ requestID: UUID) async throws
    func declineFriendRequest(_ requestID: UUID) async throws
}

struct SupabaseFriendService: FriendServicing {
    private let client: SupabaseClient
    private let profilePhotosBucket = "profile-photos"

    init(client: SupabaseClient? = nil) throws {
        self.client = try client ?? SupabaseClientProvider.makeClient()
    }

    func fetchFriends(for userID: UUID) async throws -> [FriendProfile] {
        let response: PostgrestResponse<[FriendshipRow]> = try await client
            .from("friendships")
            .select("id,requester_id,addressee_id,status,created_at")
            .eq("status", value: FriendshipStatus.accepted.rawValue)
            .or("requester_id.eq.\(userID.uuidString),addressee_id.eq.\(userID.uuidString)")
            .order("created_at", ascending: false)
            .execute()

        let friendIDs = response.value.map { row in
            row.requesterID == userID ? row.addresseeID : row.requesterID
        }

        return try await fetchProfiles(ids: friendIDs)
    }

    func fetchIncomingRequests(for userID: UUID) async throws -> [FriendRequest] {
        let response: PostgrestResponse<[FriendshipRow]> = try await client
            .from("friendships")
            .select("id,requester_id,addressee_id,status,created_at")
            .eq("addressee_id", value: userID)
            .eq("status", value: FriendshipStatus.pending.rawValue)
            .order("created_at", ascending: false)
            .execute()

        let requesterIDs = response.value.map(\.requesterID)
        let profiles = try await fetchProfiles(ids: requesterIDs)
        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return response.value.compactMap { row in
            guard let profile = profilesByID[row.requesterID] else { return nil }
            return FriendRequest(id: row.id, user: profile)
        }
    }

    func searchUsers(matching query: String, currentUserID: UUID) async throws -> [FriendSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let friendships = try await fetchFriendshipsInvolving(userID: currentUserID)
        let acceptedIDs = Set(friendships.filter { $0.status == FriendshipStatus.accepted.rawValue }.map { row in
            row.requesterID == currentUserID ? row.addresseeID : row.requesterID
        })
        let sentPendingIDs = Set(friendships.filter {
            $0.status == FriendshipStatus.pending.rawValue && $0.requesterID == currentUserID
        }.map(\.addresseeID))
        let incomingPendingIDs = Set(friendships.filter {
            $0.status == FriendshipStatus.pending.rawValue && $0.addresseeID == currentUserID
        }.map(\.requesterID))

        let response: PostgrestResponse<[ProfileFriendRow]> = try await client
            .from("profiles")
            .select("id,first_name,last_name,email,avatar_path")
            .neq("id", value: currentUserID)
            .limit(40)
            .execute()

        return try await withThrowingTaskGroup(of: FriendSearchResult?.self) { group in
            for row in response.value where !acceptedIDs.contains(row.id) && !incomingPendingIDs.contains(row.id) {
                guard normalizedQuery.isEmpty || row.searchText.contains(normalizedQuery) else {
                    continue
                }

                group.addTask {
                    let profile = try await makeFriendProfile(from: row)
                    return FriendSearchResult(
                        profile: profile,
                        hasSentRequest: sentPendingIDs.contains(row.id)
                    )
                }
            }

            var results: [FriendSearchResult] = []
            for try await result in group {
                if let result { results.append(result) }
            }

            return results.sorted { $0.profile.name.localizedCaseInsensitiveCompare($1.profile.name) == .orderedAscending }
        }
    }

    func sendFriendRequest(from requesterID: UUID, to addresseeID: UUID) async throws {
        let insert = FriendshipInsert(
            requesterID: requesterID,
            addresseeID: addresseeID,
            status: FriendshipStatus.pending.rawValue
        )

        try await client
            .from("friendships")
            .insert(insert)
            .execute()
    }

    func acceptFriendRequest(_ requestID: UUID) async throws {
        try await client
            .from("friendships")
            .update(FriendshipStatusUpdate(status: FriendshipStatus.accepted.rawValue))
            .eq("id", value: requestID)
            .execute()
    }

    func declineFriendRequest(_ requestID: UUID) async throws {
        try await client
            .from("friendships")
            .delete()
            .eq("id", value: requestID)
            .execute()
    }

    private func fetchFriendshipsInvolving(userID: UUID) async throws -> [FriendshipRow] {
        let response: PostgrestResponse<[FriendshipRow]> = try await client
            .from("friendships")
            .select("id,requester_id,addressee_id,status,created_at")
            .or("requester_id.eq.\(userID.uuidString),addressee_id.eq.\(userID.uuidString)")
            .execute()

        return response.value
    }

    private func fetchProfiles(ids: [UUID]) async throws -> [FriendProfile] {
        guard !ids.isEmpty else { return [] }

        let response: PostgrestResponse<[ProfileFriendRow]> = try await client
            .from("profiles")
            .select("id,first_name,last_name,email,avatar_path")
            .in("id", values: ids)
            .execute()

        return try await withThrowingTaskGroup(of: FriendProfile?.self) { group in
            for row in response.value {
                group.addTask {
                    try await makeFriendProfile(from: row)
                }
            }

            var profiles: [FriendProfile] = []
            for try await profile in group {
                if let profile { profiles.append(profile) }
            }

            let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
            return profiles.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
        }
    }

    private func makeFriendProfile(from row: ProfileFriendRow) async throws -> FriendProfile {
        let avatarURL: URL?
        if let avatarPath = row.avatarPath, !avatarPath.isEmpty {
            avatarURL = try await client.storage
                .from(profilePhotosBucket)
                .createSignedURL(path: avatarPath, expiresIn: 3600)
        } else {
            avatarURL = nil
        }

        return FriendProfile(
            id: row.id,
            name: row.displayName,
            email: row.email,
            avatarURL: avatarURL
        )
    }
}

private enum FriendshipStatus: String {
    case pending
    case accepted
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

private struct FriendshipStatusUpdate: Encodable {
    let status: String
}

private struct ProfileFriendRow: Decodable {
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

        return fullName.isEmpty ? email : fullName
    }

    var searchText: String {
        "\(displayName) \(email)".lowercased()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case avatarPath = "avatar_path"
    }
}
