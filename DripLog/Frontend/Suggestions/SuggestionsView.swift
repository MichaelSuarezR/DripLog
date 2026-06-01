import SwiftUI

struct SuggestionsView: View {
    let suggestions: OutfitSuggestions?
    let isLoading: Bool
    let errorMessage: String?
    let onClose: () -> Void
    let onRetry: () -> Void

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            header

            if isLoading {
                Spacer()
                ProgressView("Building suggestions...")
                    .font(.headline)
                Spacer()
            } else if let errorMessage {
                errorView(message: errorMessage)
            } else if let suggestions {
                suggestionContent(suggestions)
            }
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("Outfits For You")
                .font(AppFont.uiBold(size: 30))
                .foregroundStyle(.black)
            Spacer()
            RunningFiguresView()
                .frame(height: 64)
        }
        .padding(.horizontal, 20)
        .padding(.top, 64)
        .padding(.bottom, 16)
    }

    // MARK: - Main content

    private func suggestionContent(_ s: OutfitSuggestions) -> some View {
        VStack(spacing: 0) {
            // Static outfit cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    closetCard(imageURL: s.leftOutfit.imageURL, tags: s.leftOutfit.categories)
                    inspirationCard(look: s.centerInspiration)
                    closetCard(imageURL: s.rightOutfit.imageURL, tags: s.rightOutfit.categories)
                }
                .padding(.horizontal, 20)
            }

            // Swipeable info cards
            TabView(selection: $currentPage) {
                whyItWorksCard(explanation: s.explanation)
                    .padding(.horizontal, 20)
                    .tag(0)

                weatherContextCard(weather: s.weather)
                    .padding(.horizontal, 20)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)
            .clipped()
            .padding(.top, 20)

            paginationDots
                .padding(.top, 12)

            Spacer()

            Button(action: onClose) {
                Text("Done")
                    .font(AppFont.uiBold(size: 18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColor.accentOrange, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
    }

    // MARK: - Outfit cards

    private func closetCard(imageURL: URL, tags: [String]) -> some View {
        VStack(alignment: .center, spacing: 10) {
            CachedAsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            }
            .frame(width: 260, height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .clipped()

            Text("Your Closet")
                .font(AppFont.uiBold(size: 14))
                .foregroundStyle(AppColor.placeholderBlue)

            HStack(spacing: 6) {
                ForEach(tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(AppFont.uiRegular(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColor.placeholderBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func inspirationCard(look: InspirationLook) -> some View {
        VStack(alignment: .center, spacing: 10) {
            CachedAsyncImage(url: look.imageURL) { image in
                image.resizable().scaledToFill()
            }
            .frame(width: 260, height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .clipped()

            Text("Inspiration")
                .font(AppFont.uiBold(size: 14))
                .foregroundStyle(AppColor.placeholderBlue)

            HStack(spacing: 6) {
                ForEach(look.categories.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(AppFont.uiRegular(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColor.placeholderBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    // MARK: - Info cards (swipeable)

    private func whyItWorksCard(explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why it works")
                .font(AppFont.uiBold(size: 16))
                .foregroundStyle(.white)
            Text(explanation)
                .font(AppFont.uiRegular(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColor.placeholderBlue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func weatherContextCard(weather: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weather Context")
                .font(AppFont.uiBold(size: 16))
                .foregroundStyle(.white)
            if let location = weather.locationName, !location.isEmpty {
                Text(location)
                    .font(AppFont.uiBold(size: 14))
                    .foregroundStyle(.white)
            }
            Text("\(weather.summary) \(weather.temperatureText)")
                .font(AppFont.uiRegular(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ForEach(weather.tags.prefix(4), id: \.self) { tag in
                    Text(tag.capitalized)
                        .font(AppFont.uiRegular(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AppColor.placeholderBlue.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColor.placeholderBlue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Pagination dots

    private var paginationDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.black : Color.black.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text(message)
                .font(.headline)
                .foregroundStyle(.black)
            Button("Try Again", action: onRetry)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct RunningFiguresView: View {
    private let poses = ["run_pose1", "run_pose2", "run_pose3"]
    private let frameDuration = 0.18

    var body: some View {
        TimelineView(.animation) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / frameDuration)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { slot in
                    Image(poses[(step + slot) % poses.count])
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 64)
                }
            }
        }
    }
}
