//
//  OutfitService.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Supabase
import UIKit
import Vision

struct OutfitPhoto: Identifiable {
    let id: UUID
    let imagePath: String
    let image: UIImage
    let tags: [String]
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
    func uploadOutfit(_ image: UIImage, tags: [String], for userID: UUID) async throws -> OutfitPhoto
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
            .select("id,image_path,caption")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()

        var photos: [OutfitPhoto] = []

        for row in response.value {
            let data = try await client.storage
                .from(bucketName)
                .download(path: row.imagePath)

            if let image = UIImage(data: data) {
                photos.append(
                    OutfitPhoto(
                        id: row.id,
                        imagePath: row.imagePath,
                        image: image,
                        tags: row.tags
                    )
                )
            }
        }

        return photos
    }

    func uploadOutfit(_ image: UIImage, tags: [String], for userID: UUID) async throws -> OutfitPhoto {
        let outfitID = UUID()
        let uploadPayload = try Self.makeUploadPayload(for: image, userID: userID, outfitID: outfitID)
        let normalizedTags = tags.map(Self.normalizeTag(_:)).filter { !$0.isEmpty }

        try await client.storage
            .from(bucketName)
            .upload(
                uploadPayload.path,
                data: uploadPayload.data,
                options: FileOptions(contentType: uploadPayload.contentType, upsert: false)
            )

        let insert = OutfitInsert(
            id: outfitID,
            userID: userID,
            imagePath: uploadPayload.path,
            caption: Self.encodeTags(normalizedTags)
        )
        try await client
            .from("outfits")
            .insert(insert)
            .execute()

        return OutfitPhoto(
            id: outfitID,
            imagePath: uploadPayload.path,
            image: uploadPayload.previewImage,
            tags: normalizedTags
        )
    }

    private static func makeUploadPayload(for image: UIImage, userID: UUID, outfitID: UUID) throws -> UploadPayload {
        let basePath = "\(userID.uuidString.lowercased())/\(outfitID.uuidString.lowercased())"

        if
            let cutoutImage = PersonCutoutProcessor.makeCutout(from: image),
            let pngData = cutoutImage.pngData()
        {
            return UploadPayload(
                path: "\(basePath).png",
                data: pngData,
                contentType: "image/png",
                previewImage: cutoutImage
            )
        }

        guard let imageData = image.jpegData(compressionQuality: 0.82) else {
            throw OutfitError.missingImageData
        }

        return UploadPayload(
            path: "\(basePath).jpg",
            data: imageData,
            contentType: "image/jpeg",
            previewImage: image
        )
    }

    private static func normalizeTag(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func encodeTags(_ tags: [String]) -> String? {
        guard !tags.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(tags) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private struct OutfitRow: Decodable {
    let id: UUID
    let imagePath: String
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case imagePath = "image_path"
        case caption
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imagePath = try container.decode(String.self, forKey: .imagePath)

        if let caption = try container.decodeIfPresent(String.self, forKey: .caption) {
            tags = (try? JSONDecoder().decode([String].self, from: Data(caption.utf8))) ?? []
        } else {
            tags = []
        }
    }
}

private struct OutfitInsert: Encodable {
    let id: UUID
    let userID: UUID
    let imagePath: String
    let caption: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case imagePath = "image_path"
        case caption
    }
}

private struct UploadPayload {
    let path: String
    let data: Data
    let contentType: String
    let previewImage: UIImage
}

private enum PersonCutoutProcessor {
    private static let context = CIContext()

    static func makeCutout(from image: UIImage) -> UIImage? {
        let normalizedImage = image.normalizedUpImage()

        guard let inputImage = CIImage(image: normalizedImage) else {
            return nil
        }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(ciImage: inputImage)

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let maskBuffer = request.results?.first?.pixelBuffer else {
            return nil
        }

        let maskImage = CIImage(cvPixelBuffer: maskBuffer)
        let scaleX = inputImage.extent.width / maskImage.extent.width
        let scaleY = inputImage.extent.height / maskImage.extent.height
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let transparentBackground = CIImage(color: .clear).cropped(to: inputImage.extent)
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = inputImage
        blendFilter.backgroundImage = transparentBackground
        blendFilter.maskImage = scaledMask

        guard
            let outputImage = blendFilter.outputImage,
            let cgImage = context.createCGImage(outputImage, from: inputImage.extent)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: normalizedImage.scale, orientation: .up)
    }
}

private extension UIImage {
    func normalizedUpImage() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = scale
        rendererFormat.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
