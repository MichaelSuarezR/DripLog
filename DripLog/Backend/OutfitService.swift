//
//  OutfitService.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import Foundation
import CoreLocation
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Supabase
import UIKit
import Vision

struct OutfitPhoto: Identifiable {
    let id: UUID
    let imagePath: String
    let imageURL: URL
    let tags: [String]
    let customTags: [String]
    let categories: [String]
    let weather: [String]
    let occasion: [String]
    let colors: [String]

    /// Compressed 600px-wide version of the image for use in suggestion cards.
    /// Falls back to full-res if the URL can't be transformed.
    var thumbnailURL: URL {
        imageURL.appendingSupabaseTransform(width: 600, quality: 75) ?? imageURL
    }
}

struct OutfitMetadata {
    let customTags: [String]
    let categories: [String]
    let weather: [String]
    let occasion: [String]
    let colors: [String]

    var allTags: [String] {
        var ordered = categories
        ordered.append(contentsOf: weather)
        ordered.append(contentsOf: occasion)
        ordered.append(contentsOf: colors)
        ordered.append(contentsOf: customTags)
        return Array(NSOrderedSet(array: ordered)) as? [String] ?? ordered
    }

    static let empty = OutfitMetadata(
        customTags: [],
        categories: [],
        weather: [],
        occasion: [],
        colors: []
    )
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
    func uploadOutfit(_ image: UIImage, metadata: OutfitMetadata, for userID: UUID) async throws -> OutfitPhoto
    func updateOutfitMetadata(_ metadata: OutfitMetadata, for outfitID: UUID) async throws
    func deleteOutfit(_ photo: OutfitPhoto) async throws
}

struct InspirationLook: Identifiable {
    let id: UUID
    let imageURL: URL
    let caption: String
    let categories: [String]
    let weather: [String]
    let occasion: [String]
    let colors: [String]
    let gender: String
}

struct WeatherSnapshot {
    let locationName: String?
    let summary: String
    let tags: [String]
    let temperatureText: String
}

struct OutfitSuggestions {
    let leftOutfit: OutfitPhoto
    let centerInspiration: InspirationLook
    let rightOutfit: OutfitPhoto
    let weather: WeatherSnapshot
    let explanation: String
}

enum SuggestionError: LocalizedError {
    case noOutfits
    case noInspirationLooks
    case missingLocation
    case backendFailure(String)

    var errorDescription: String? {
        switch self {
        case .noOutfits:
            "Add at least one outfit before asking for suggestions."
        case .noInspirationLooks:
            "No inspiration looks are available yet."
        case .missingLocation:
            "Location access is required so suggestions can use the real weather."
        case .backendFailure(let message):
            message
        }
    }
}

protocol SuggestionServicing {
    func makeSuggestions(for user: AppUser, outfitPhotos: [OutfitPhoto]) async throws -> OutfitSuggestions
}

protocol AutoTagServicing {
    func autoTag(image: UIImage) async throws -> OutfitMetadata
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
            .select("id,image_path,caption,categories,weather,occasion,colors")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()

        guard !response.value.isEmpty else { return [] }

        let signedURLs: [URL]
        do {
            signedURLs = try await client.storage
                .from(bucketName)
                .createSignedURLs(paths: response.value.map(\.imagePath), expiresIn: 3600)
        } catch {
            signedURLs = await createSignedURLsOneByOne(for: response.value.map(\.imagePath))
        }

        return zip(response.value, signedURLs).map { row, signedURL in
            OutfitPhoto(
                id: row.id,
                imagePath: row.imagePath,
                imageURL: signedURL,
                tags: row.metadata.allTags,
                customTags: row.metadata.customTags,
                categories: row.metadata.categories,
                weather: row.metadata.weather,
                occasion: row.metadata.occasion,
                colors: row.metadata.colors
            )
        }
    }

    private func createSignedURLsOneByOne(for imagePaths: [String]) async -> [URL] {
        await withTaskGroup(of: (Int, URL).self) { group in
            for (index, imagePath) in imagePaths.enumerated() {
                group.addTask {
                    if let signedURL = try? await client.storage
                        .from(bucketName)
                        .createSignedURL(path: imagePath, expiresIn: 3600) {
                        return (index, signedURL)
                    }

                    let publicURL = (try? client.storage
                        .from(bucketName)
                        .getPublicURL(path: imagePath)) ?? URL(fileURLWithPath: imagePath)
                    return (index, publicURL)
                }
            }

            var orderedURLs = Array<URL?>(repeating: nil, count: imagePaths.count)
            for await (index, signedURL) in group {
                orderedURLs[index] = signedURL
            }
            return orderedURLs.compactMap { $0 }
        }
    }

    func uploadOutfit(_ image: UIImage, metadata: OutfitMetadata, for userID: UUID) async throws -> OutfitPhoto {
        let outfitID = UUID()
        let uploadPayload = try Self.makeUploadPayload(for: image, userID: userID, outfitID: outfitID)
        let normalizedMetadata = Self.normalizeMetadata(metadata)

        try await uploadPhoto(uploadPayload)

        let insert = OutfitInsert(
            id: outfitID,
            userID: userID,
            imagePath: uploadPayload.path,
            caption: Self.encodeTags(normalizedMetadata.customTags),
            categories: normalizedMetadata.categories,
            weather: normalizedMetadata.weather,
            occasion: normalizedMetadata.occasion,
            colors: normalizedMetadata.colors,
            visibility: OutfitVisibility.publicProfile.title
        )
        try await client
            .from("outfits")
            .insert(insert)
            .execute()

        let signedURL = (try? await client.storage
            .from(bucketName)
            .createSignedURL(path: uploadPayload.path, expiresIn: 3600))
            ?? ((try? client.storage.from(bucketName).getPublicURL(path: uploadPayload.path)) ?? URL(fileURLWithPath: uploadPayload.path))

        return OutfitPhoto(
            id: outfitID,
            imagePath: uploadPayload.path,
            imageURL: signedURL,
            tags: normalizedMetadata.allTags,
            customTags: normalizedMetadata.customTags,
            categories: normalizedMetadata.categories,
            weather: normalizedMetadata.weather,
            occasion: normalizedMetadata.occasion,
            colors: normalizedMetadata.colors
        )
    }

    private func uploadPhoto(_ uploadPayload: UploadPayload) async throws {
        var lastError: Error?

        for attempt in 1...3 {
            do {
                try await client.storage
                    .from(bucketName)
                    .upload(
                        uploadPayload.path,
                        data: uploadPayload.data,
                        options: FileOptions(contentType: uploadPayload.contentType, upsert: false)
                    )
                return
            } catch {
                lastError = error
                guard Self.shouldRetryUpload(error), attempt < 3 else {
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 700_000_000)
            }
        }

        if let lastError {
            throw lastError
        }
    }

    private static func shouldRetryUpload(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
                || urlError.code == .networkConnectionLost
                || urlError.code == .cannotConnectToHost
        }

        let description = String(describing: error)
        return description.contains("NSURLErrorDomain Code=-1001")
            || description.localizedCaseInsensitiveContains("timed out")
    }

    func updateOutfitMetadata(_ metadata: OutfitMetadata, for outfitID: UUID) async throws {
        let normalizedMetadata = Self.normalizeMetadata(metadata)

        try await client
            .from("outfits")
            .update(
                OutfitUpdate(
                    caption: Self.encodeTags(normalizedMetadata.customTags),
                    categories: normalizedMetadata.categories,
                    weather: normalizedMetadata.weather,
                    occasion: normalizedMetadata.occasion,
                    colors: normalizedMetadata.colors
                )
            )
            .eq("id", value: outfitID)
            .execute()
    }

    func deleteOutfit(_ photo: OutfitPhoto) async throws {
        try await client.storage
            .from(bucketName)
            .remove(paths: [photo.imagePath])

        try await client
            .from("outfits")
            .delete()
            .eq("id", value: photo.id)
            .execute()
    }

    private static func makeUploadPayload(for image: UIImage, userID: UUID, outfitID: UUID) throws -> UploadPayload {
        let basePath = "\(userID.uuidString.lowercased())/\(outfitID.uuidString.lowercased())"
        let uploadImage = image.resizedForUpload(maxDimension: 900)

        guard let imageData = uploadImage.jpegData(compressionQuality: 0.58) else {
            throw OutfitError.missingImageData
        }

        return UploadPayload(
            path: "\(basePath).jpg",
            data: imageData,
            contentType: "image/jpeg",
            previewImage: uploadImage
        )
    }

    private static func normalizeTag(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeMetadata(_ metadata: OutfitMetadata) -> OutfitMetadata {
        OutfitMetadata(
            customTags: metadata.customTags.map(normalizeTag(_:)).filter { !$0.isEmpty },
            categories: metadata.categories.map(normalizeTag(_:)).filter { !$0.isEmpty },
            weather: metadata.weather.map(normalizeTag(_:)).filter { !$0.isEmpty },
            occasion: metadata.occasion.map(normalizeTag(_:)).filter { !$0.isEmpty },
            colors: metadata.colors.map(normalizeTag(_:)).filter { !$0.isEmpty }
        )
    }

    private static func encodeTags(_ tags: [String]) -> String? {
        guard !tags.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(tags) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct SupabaseSuggestionService: SuggestionServicing {
    private let client: SupabaseClient
    private let configuration: SupabaseConfiguration

    init(client: SupabaseClient? = nil, configuration: SupabaseConfiguration? = .current) throws {
        self.client = try client ?? SupabaseClientProvider.makeClient(configuration: configuration)
        guard let configuration else {
            throw AuthError.missingSupabaseConfiguration
        }
        self.configuration = configuration
    }

    func makeSuggestions(for user: AppUser, outfitPhotos: [OutfitPhoto]) async throws -> OutfitSuggestions {
        guard !outfitPhotos.isEmpty else {
            throw SuggestionError.noOutfits
        }

        return try await invokeAISuggestions(for: user, outfitPhotos: outfitPhotos)
    }

    private func invokeAISuggestions(for user: AppUser, outfitPhotos: [OutfitPhoto]) async throws -> OutfitSuggestions {
        guard let accessToken = client.auth.currentSession?.accessToken else {
            throw SuggestionError.backendFailure("You need to be logged in to build suggestions.")
        }

        let coordinates: CLLocation
        do {
            coordinates = try await CurrentWeatherService.fetchCoordinates()
        } catch {
            throw SuggestionError.missingLocation
        }
        let locality = await CurrentWeatherService.fetchLocality(for: coordinates)

        let payload = SuggestionFunctionRequest(
            userID: user.id,
            latitude: coordinates.coordinate.latitude,
            longitude: coordinates.coordinate.longitude,
            locality: locality,
            localDate: Self.localDateString()
        )

        var request = URLRequest(url: configuration.projectURL.appending(path: "functions/v1/outfit-suggestions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SuggestionError.backendFailure("The suggestions service returned an invalid response.")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let backendError = try? JSONDecoder().decode(FunctionErrorResponse.self, from: data)
            throw SuggestionError.backendFailure(backendError?.error ?? "The suggestions service failed.")
        }

        let decoded = try JSONDecoder().decode(SuggestionFunctionResponse.self, from: data)

        guard
            let leftOutfit = outfitPhotos.first(where: { $0.id == decoded.leftOutfitID }),
            let rightOutfit = outfitPhotos.first(where: { $0.id == decoded.rightOutfitID }),
            let inspirationURL = URL(string: decoded.inspiration.imageURL)
                .flatMap({ $0.appendingSupabaseTransform(width: 600, quality: 75) })
                ?? URL(string: decoded.inspiration.imageURL)
        else {
            throw SuggestionError.backendFailure("The suggestions service returned malformed outfit data.")
        }

        let inspiration = InspirationLook(
            id: decoded.inspiration.id,
            imageURL: inspirationURL,
            caption: decoded.inspiration.caption,
            categories: decoded.inspiration.categories,
            weather: decoded.inspiration.weather,
            occasion: decoded.inspiration.occasion,
            colors: decoded.inspiration.colors,
            gender: decoded.inspiration.gender
        )

        let weather = WeatherSnapshot(
            locationName: decoded.weather.locationName,
            summary: decoded.weather.summary,
            tags: decoded.weather.tags,
            temperatureText: decoded.weather.temperatureText
        )

        return OutfitSuggestions(
            leftOutfit: leftOutfit,
            centerInspiration: inspiration,
            rightOutfit: rightOutfit,
            weather: weather,
            explanation: decoded.explanation
        )
    }

    private static func localDateString(for date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

struct SupabaseAutoTagService: AutoTagServicing {
    private let client: SupabaseClient
    private let configuration: SupabaseConfiguration

    init(client: SupabaseClient? = nil, configuration: SupabaseConfiguration? = .current) throws {
        self.client = try client ?? SupabaseClientProvider.makeClient(configuration: configuration)
        guard let configuration else {
            throw AuthError.missingSupabaseConfiguration
        }
        self.configuration = configuration
    }

    func autoTag(image: UIImage) async throws -> OutfitMetadata {
        guard let accessToken = client.auth.currentSession?.accessToken else {
            throw AutoTagError.notLoggedIn
        }

        guard let imageData = resizedImageData(image) else {
            throw AutoTagError.imageEncodingFailed
        }

        let payload = AutoTagRequest(imageBase64: imageData.base64EncodedString(), mimeType: "image/jpeg")

        var request = URLRequest(url: configuration.projectURL.appending(path: "functions/v1/auto-tag-outfit"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw AutoTagError.backendFailed
        }

        let decoded = try JSONDecoder().decode(AutoTagResponse.self, from: data)
        return OutfitMetadata(
            customTags: [],
            categories: decoded.categories,
            weather: decoded.weather,
            occasion: decoded.occasion,
            colors: decoded.colors
        )
    }

    private func resizedImageData(_ image: UIImage, maxDimension: CGFloat = 1024) -> Data? {
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
            .jpegData(compressionQuality: 0.7)
    }
}

enum AutoTagError: LocalizedError {
    case notLoggedIn
    case imageEncodingFailed
    case backendFailed

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:       "You must be logged in to use auto-tagging."
        case .imageEncodingFailed: "Could not encode the photo for auto-tagging."
        case .backendFailed:     "Auto-tagging failed."
        }
    }
}

private struct AutoTagRequest: Encodable {
    let imageBase64: String
    let mimeType: String

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case mimeType = "mime_type"
    }
}

private struct AutoTagResponse: Decodable {
    let categories: [String]
    let weather: [String]
    let occasion: [String]
    let colors: [String]
}

private struct OutfitRow: Decodable {
    let id: UUID
    let imagePath: String
    let metadata: OutfitMetadata

    enum CodingKeys: String, CodingKey {
        case id
        case imagePath = "image_path"
        case caption
        case categories
        case weather
        case occasion
        case colors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imagePath = try container.decode(String.self, forKey: .imagePath)

        let customTags: [String]
        if let caption = try container.decodeIfPresent(String.self, forKey: .caption) {
            customTags = (try? JSONDecoder().decode([String].self, from: Data(caption.utf8))) ?? []
        } else {
            customTags = []
        }

        metadata = OutfitMetadata(
            customTags: customTags,
            categories: try container.decodeIfPresent([String].self, forKey: .categories) ?? [],
            weather: try container.decodeIfPresent([String].self, forKey: .weather) ?? [],
            occasion: try container.decodeIfPresent([String].self, forKey: .occasion) ?? [],
            colors: try container.decodeIfPresent([String].self, forKey: .colors) ?? []
        )
    }
}

private struct SuggestionFunctionRequest: Encodable {
    let userID: UUID
    let latitude: Double?
    let longitude: Double?
    let locality: String?
    let localDate: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case latitude
        case longitude
        case locality
        case localDate = "local_date"
    }
}

private struct FunctionErrorResponse: Decodable {
    let error: String
}

private struct SuggestionFunctionResponse: Decodable {
    let leftOutfitID: UUID
    let rightOutfitID: UUID
    let inspiration: SuggestionFunctionInspiration
    let weather: SuggestionFunctionWeather
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case leftOutfitID = "left_outfit_id"
        case rightOutfitID = "right_outfit_id"
        case inspiration
        case weather
        case explanation
    }
}

private struct SuggestionFunctionInspiration: Decodable {
    let id: UUID
    let imageURL: String
    let caption: String
    let categories: [String]
    let weather: [String]
    let occasion: [String]
    let colors: [String]
    let gender: String

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "image_url"
        case caption
        case categories
        case weather
        case occasion
        case colors
        case gender
    }
}

private struct SuggestionFunctionWeather: Decodable {
    let locationName: String?
    let summary: String
    let tags: [String]
    let temperatureText: String

    enum CodingKeys: String, CodingKey {
        case locationName = "location_name"
        case summary
        case tags
        case temperatureText = "temperature_text"
    }
}

private struct OutfitInsert: Encodable {
    let id: UUID
    let userID: UUID
    let imagePath: String
    let caption: String?
    let categories: [String]
    let weather: [String]
    let occasion: [String]
    let colors: [String]
    let visibility: String

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
    }
}

private struct OutfitUpdate: Encodable {
    let caption: String?
    let categories: [String]
    let weather: [String]
    let occasion: [String]
    let colors: [String]
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
    func resizedForUpload(maxDimension: CGFloat) -> UIImage {
        let normalized = normalizedUpImage()
        let longestSide = max(normalized.size.width, normalized.size.height)

        guard longestSide > maxDimension else {
            return normalized
        }

        let scaleFactor = maxDimension / longestSide
        let targetSize = CGSize(
            width: normalized.size.width * scaleFactor,
            height: normalized.size.height * scaleFactor
        )

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        rendererFormat.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            normalized.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

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

private enum CurrentWeatherService {
    static func fetchSnapshot() async throws -> WeatherSnapshot {
        do {
            let location = try await fetchCoordinates()
            let url = makeForecastURL(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let (data, _) = try await URLSession.shared.data(from: url)
            let forecast = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            return normalizedSnapshot(from: forecast.current)
        } catch {
            return fallbackSnapshot()
        }
    }

    static func fetchCoordinates() async throws -> CLLocation {
        try await OneShotLocationProvider().requestLocation()
    }

    static func fetchLocality(for location: CLLocation) async -> String? {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            let placemark = placemarks.first
            return placemark?.locality ?? placemark?.subLocality ?? placemark?.administrativeArea
        } catch {
            return nil
        }
    }

    private static func makeForecastURL(latitude: Double, longitude: Double) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit")
        ]
        return components.url!
    }

    private static func normalizedSnapshot(from current: OpenMeteoCurrent) -> WeatherSnapshot {
        let apparent = current.apparentTemperature
        var tags: [String] = []
        let summaryPrefix: String

        switch apparent {
        case ..<55:
            tags.append("cold")
            summaryPrefix = "It is cold out,"
        case ..<70:
            tags.append("cool")
            summaryPrefix = "It is cool out,"
        case ..<82:
            tags.append("warm")
            summaryPrefix = "It is warm out,"
        default:
            tags.append("hot")
            summaryPrefix = "It is hot out,"
        }

        switch current.weatherCode {
        case 0:
            tags.append("sunny")
        case 51...67, 80...86:
            tags.append("rainy")
        case 71...77:
            tags.append("snowy")
        default:
            tags.append("cloudy")
        }

        let weatherWord = tags.dropFirst().first ?? "clear"
        return WeatherSnapshot(
            locationName: nil,
            summary: "\(summaryPrefix) \(weatherWord) conditions favor the lighter or more seasonally aligned pieces in your closet.",
            tags: tags,
            temperatureText: "(\(Int(apparent.rounded()))°F)"
        )
    }

    private static func fallbackSnapshot() -> WeatherSnapshot {
        let month = Calendar.current.component(.month, from: Date())
        let tags: [String]
        let summary: String

        switch month {
        case 12, 1, 2:
            tags = ["cold", "cloudy"]
            summary = "It looks like cooler weather,"
        case 3, 4, 5:
            tags = ["warm", "sunny"]
            summary = "It looks like mild weather,"
        case 6, 7, 8:
            tags = ["hot", "sunny"]
            summary = "It looks like warm weather,"
        default:
            tags = ["cool", "cloudy"]
            summary = "It looks like transitional weather,"
        }

        return WeatherSnapshot(
            locationName: nil,
            summary: "\(summary) so the recommendation is leaning on seasonally safe pieces.",
            tags: tags,
            temperatureText: ""
        )
    }
}

private final class OneShotLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            continuation?.resume(throwing: CLError(.denied))
            continuation = nil
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: OpenMeteoCurrent
}

private struct OpenMeteoCurrent: Decodable {
    let temperature: Double
    let apparentTemperature: Double
    let weatherCode: Int

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case weatherCode = "weather_code"
    }
}

// MARK: - URL + Supabase Transform

extension URL {
    /// Appends Supabase image transform query parameters to a Supabase storage URL.
    /// Returns nil if the URL is not a Supabase storage URL.
    func appendingSupabaseTransform(width: Int, quality: Int) -> URL? {
        guard host?.contains("supabase") == true || absoluteString.contains("/storage/v1/") else {
            return nil
        }
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        items.removeAll { $0.name == "width" || $0.name == "quality" }
        items.append(URLQueryItem(name: "width", value: "\(width)"))
        items.append(URLQueryItem(name: "quality", value: "\(quality)"))
        components?.queryItems = items
        return components?.url
    }
}
