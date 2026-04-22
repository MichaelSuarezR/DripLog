//
//  OutfitService.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import Foundation
import Supabase
import UIKit

struct OutfitPhoto: Identifiable {
    let id: UUID
    let imagePath: String
    let image: UIImage
}

enum OutfitError: LocalizedError {
    case missingImageData

    var errorDescription: String? {
        switch self {
        case .missingImageData:
            "Could not convert the photo to upload data."
        }
    }
}

protocol OutfitServicing {
    func fetchOutfits(for userID: UUID) async throws -> [OutfitPhoto]
    func uploadOutfit(_ image: UIImage, for userID: UUID) async throws -> OutfitPhoto
}

struct SupabaseOutfitService: OutfitServicing {
    private let client: SupabaseClient
    private let bucketName = "outfit-photos"

    init(client: SupabaseClient? = nil) throws {
        self.client = try client ?? SupabaseClientProvider.makeClient()
    }

    func fetchOutfits(for userID: UUID) async throws -> [OutfitPhoto] {
        let response: PostgrestResponse<[OutfitRow]> = try await client
            .from("outfits")
            .select("id,image_path")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()

        var photos: [OutfitPhoto] = []

        for row in response.value {
            let data = try await client.storage
                .from(bucketName)
                .download(path: row.imagePath)

            if let image = UIImage(data: data) {
                photos.append(OutfitPhoto(id: row.id, imagePath: row.imagePath, image: image))
            }
        }

        return photos
    }

    func uploadOutfit(_ image: UIImage, for userID: UUID) async throws -> OutfitPhoto {
        guard let imageData = image.jpegData(compressionQuality: 0.82) else {
            throw OutfitError.missingImageData
        }

        let outfitID = UUID()
        let imagePath = "\(userID.uuidString)/\(outfitID.uuidString).jpg"

        try await client.storage
            .from(bucketName)
            .upload(
                imagePath,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: false)
            )

        let insert = OutfitInsert(id: outfitID, userID: userID, imagePath: imagePath)
        try await client
            .from("outfits")
            .insert(insert)
            .execute()

        return OutfitPhoto(id: outfitID, imagePath: imagePath, image: image)
    }
}

private struct OutfitRow: Decodable {
    let id: UUID
    let imagePath: String

    enum CodingKeys: String, CodingKey {
        case id
        case imagePath = "image_path"
    }
}

private struct OutfitInsert: Encodable {
    let id: UUID
    let userID: UUID
    let imagePath: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case imagePath = "image_path"
    }
}
