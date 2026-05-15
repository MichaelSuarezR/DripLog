import Foundation
import Supabase

// MARK: - FeedPost

struct FeedPost: Identifiable {
    let id: UUID
    let authorName: String
    let imageURL: URL
    let tags: [String]
    let createdAt: Date
}

// MARK: - FeedServicing

protocol FeedServicing {
    func fetchFeedPosts(page: Int) async throws -> [FeedPost]
}

// MARK: - SupabaseFeedService

struct SupabaseFeedService: FeedServicing {
    private let client: SupabaseClient
    private let bucketName = "outfit-photos"
    private let pageSize = 5

    init(client: SupabaseClient? = nil) throws {
        self.client = try client ?? SupabaseClientProvider.makeClient()
    }

    func fetchFeedPosts(page: Int) async throws -> [FeedPost] {
        let from = page * pageSize
        let to = from + pageSize - 1

        let rows: [FeedRow] = try await client
            .from("outfits")
            .select("id,image_path,caption,categories,weather,occasion,colors,created_at,profiles(name)")
            .order("created_at", ascending: false)
            .range(from: from, to: to)
            .execute()
            .value

        let posts: [FeedPost] = try await withThrowingTaskGroup(of: FeedPost?.self) { group in
            for row in rows {
                group.addTask {
                    let signedURL = try await self.client.storage
                        .from(self.bucketName)
                        .createSignedURL(
                            path: row.imagePath,
                            expiresIn: 3600,
                            transform: TransformOptions(width: 600, quality: 75)
                        )
                    let allTags = (row.categories + row.weather + row.occasion + row.colors)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    return FeedPost(
                        id: row.id,
                        authorName: row.profile?.name ?? "user",
                        imageURL: signedURL,
                        tags: allTags,
                        createdAt: row.createdAt
                    )
                }
            }

            var results: [FeedPost] = []
            for try await post in group {
                if let post { results.append(post) }
            }
            return results.sorted { $0.createdAt > $1.createdAt }
        }

        return posts
    }
}

// MARK: - Private row types

private struct FeedRow: Decodable {
    let id: UUID
    let imagePath: String
    let categories: [String]
    let weather: [String]
    let occasion: [String]
    let colors: [String]
    let createdAt: Date
    let profile: ProfileSnippet?

    enum CodingKeys: String, CodingKey {
        case id
        case imagePath = "image_path"
        case categories
        case weather
        case occasion
        case colors
        case createdAt = "created_at"
        case profile = "profiles"
    }
}

private struct ProfileSnippet: Decodable {
    let name: String
}
