import SwiftUI

struct SuggestionsView: View {
    let suggestions: OutfitSuggestions?
    let isLoading: Bool
    let errorMessage: String?
    let onClose: () -> Void
    let onRetry: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                header

                if isLoading {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView("Building suggestions...")
                            .font(.headline)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let errorMessage {
                    VStack(alignment: .leading, spacing: 14) {
                        Spacer()
                        Text(errorMessage)
                            .font(.headline)
                            .foregroundStyle(.black)
                        Button("Try Again") {
                            onRetry()
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                } else if let suggestions {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            Text("Randomized Outfits")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    closetSuggestionCard(
                                        imageURL: suggestions.leftOutfit.imageURL,
                                        title: "Your Closet",
                                        detail: cardDetail(for: suggestions.leftOutfit.tags)
                                    )
                                    inspirationSuggestionCard(look: suggestions.centerInspiration)
                                    closetSuggestionCard(
                                        imageURL: suggestions.rightOutfit.imageURL,
                                        title: "Your Closet",
                                        detail: cardDetail(for: suggestions.rightOutfit.tags)
                                    )
                                }
                                .padding(.horizontal, 18)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Why it works")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(suggestions.explanation)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.black.opacity(0.68))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 20)

                            weatherCard(for: suggestions.weather)
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .frame(height: 71)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 21))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Suggestions")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black)

                Spacer()

                Color.clear
                    .frame(width: 21, height: 21)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Cards

    private func closetSuggestionCard(imageURL: URL, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color.black.opacity(0.08)
                }
            }
            .frame(width: 286, height: 376)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipped()

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.black.opacity(0.68))
                    .frame(width: 250)
            }
        }
    }

    private func inspirationSuggestionCard(look: InspirationLook) -> some View {
        VStack(spacing: 12) {
            AsyncImage(url: look.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.10))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.black.opacity(0.28))
                        }
                case .empty:
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.08))
                        .overlay { ProgressView() }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 286, height: 376)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 6) {
                Text("Inspiration")
                    .font(.headline.weight(.semibold))
                Text(cardDetail(for: look.categories))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.black.opacity(0.68))
                    .frame(width: 250)
            }
        }
    }

    private func weatherCard(for weather: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weather Context")
                .font(.headline.weight(.semibold))
            if let locationName = weather.locationName, !locationName.isEmpty {
                Text(locationName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
            Text("\(weather.summary) \(weather.temperatureText)")
                .font(.footnote)
                .foregroundStyle(Color.black.opacity(0.68))
            Text(weather.tags.joined(separator: " • "))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.27))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Helpers

    private func cardDetail(for tags: [String]) -> String {
        let trimmed = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if trimmed.isEmpty { return "A clean option from your closet." }
        return trimmed.prefix(3).joined(separator: " • ")
    }
}