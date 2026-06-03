// ProfileTab.swift — FULL FILE

import SwiftUI

struct ProfileTab: View {
    let user: AppUser
    let outfitPhotos: [OutfitPhoto]
    let isLoadingOutfits: Bool
    let errorMessage: String?
    let profilePhotoURL: URL?
    let onLogOut: () -> Void
    let onEditOutfit: (OutfitPhoto) -> Void
    let onAskForSuggestions: () -> Void
    let onProfileTapped: () -> Void
    let onLoadOutfits: () async -> Void
    let onRefreshOutfits: () async -> Void

    @EnvironmentObject private var tutorialManager: TutorialManager  // NEW

    @State private var isFilterPresented = false
    @State private var filters = ClosetFilters()

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerRow
                    inspirationBanner
                        .tutorialAnchor(step: .generateOutfit)  // NEW
                    closetHeader
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    outfitsSection
                        .tutorialAnchor(step: .closetGrid)      // NEW
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
            .background(Color.white)
            .onAppear {
                Task {
                    await onLoadOutfits()
                }
            }
            .refreshable {
                await onRefreshOutfits()
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $isFilterPresented) {
                ClosetFilterView(filters: $filters)
                    .modalEntryTransition()
            }
            .animation(AppAnimation.standardSpring, value: isFilterPresented)
            // Tutorial overlays for closet steps
            .overlay {
                TutorialOverlay(
                    step: .closetGrid,
                    title: "Your closet",
                    message: "View all of your uploaded photos in your closet",
                    anchorFrame: tutorialManager.anchorFrames[.closetGrid]
                )
                TutorialOverlay(
                    step: .generateOutfit,
                    title: "Don't know what to wear?",
                    message: "Press this button whenever you don't know what to wear! You'll get:\n\n• 1 AI-generated outfit suggestion\n• 1 randomly resurfaced outfit from your closet",
                    anchorFrame: tutorialManager.anchorFrames[.generateOutfit]
                )
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .bottom) {
            Text("Hello, \(displayName)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.black)

            Spacer()

            HStack(spacing: 10) {
                Button(action: onProfileTapped) {
                    ClosetProfileAvatar(url: profilePhotoURL)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open profile")
            }
        }
        .padding(.top, 12)
    }

    private var inspirationBanner: some View {
        Button {
            onAskForSuggestions()
        } label: {
            HStack(spacing: 10) {
                Image("GenerateOutfitSparkle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)

                Text("Generate Outfit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.588, green: 0.678, blue: 0.839))

                Spacer(minLength: 0)
            }
            .padding(.leading, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color(red: 0.898, green: 0.922, blue: 0.957), Color(red: 0.945, green: 0.945, blue: 0.945)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(alignment: .topTrailing) {
                Image("GenerateOutfitFigure")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 142)
                    .padding(.top, 6)
                    .padding(.trailing, 20)
                    .allowsHitTesting(false)
            }
            .clipShape(Capsule())
            .overlay(
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let angle = (t.truncatingRemainder(dividingBy: 8) / 8) * 360
                    Capsule().strokeBorder(
                        AngularGradient(
                            colors: [
                                Color(red: 0.60, green: 0.72, blue: 0.88),
                                Color(red: 0.85, green: 0.90, blue: 0.97),
                                .white,
                                Color(red: 0.85, green: 0.90, blue: 0.97),
                                Color(red: 0.60, green: 0.72, blue: 0.88)
                            ],
                            center: .center,
                            angle: .degrees(angle)
                        ),
                        lineWidth: 1.5
                    )
                }
            )
            .shadow(color: Color(red: 0.60, green: 0.72, blue: 0.88).opacity(0.25), radius: 10, x: 0, y: 2)
            .contentShape(Capsule())
        }
        .buttonStyle(InspirationBannerButtonStyle())
    }

    private var closetHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Closet")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.black)

            HStack {
                Spacer()
                Button("Filter") {
                    isFilterPresented = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: 98, height: 34)
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
            }
        }
    }

    private var outfitsSection: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            if isLoadingOutfits && outfitPhotos.isEmpty {
                ForEach(0..<6, id: \.self) { _ in closetPlaceholderCard }
            } else if filteredOutfits.isEmpty {
                ForEach(0..<6, id: \.self) { _ in closetPlaceholderCard }
            } else {
                ForEach(filteredOutfits) { photo in
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            CachedAsyncImage(url: photo.imageURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            }
                            .frame(height: 172)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .clipped()

                            Button {
                                onEditOutfit(photo)
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(90))
                                    .frame(width: 34, height: 34)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                            .zIndex(1)
                        }
                    }
                }
            }
        }
    }

    private var closetPlaceholderCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .frame(height: 172)

            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black)
                .rotationEffect(.degrees(90))
                .frame(width: 34, height: 34)
                .padding(.top, 6)
                .padding(.trailing, 6)
        }
    }

    private var displayName: String {
        let trimmedName = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Matthew" : trimmedName
    }

    private var filteredOutfits: [OutfitPhoto] {
        guard filters.hasActiveSelections else { return outfitPhotos }
        return outfitPhotos.filter { photo in
            let normalizedTags = Set(photo.tags.map { $0.lowercased() })
            if !filters.categoryMatches(tags: normalizedTags) { return false }
            if !filters.weather.isEmpty && normalizedTags.isDisjoint(with: filters.weatherNormalized) { return false }
            if !filters.occasion.isEmpty && normalizedTags.isDisjoint(with: filters.occasionNormalized) { return false }
            if !filters.colors.isEmpty && normalizedTags.isDisjoint(with: filters.colorsNormalized) { return false }
            if !filters.custom.isEmpty && normalizedTags.isDisjoint(with: filters.customNormalized) { return false }
            return true
        }
    }
}

private struct InspirationBannerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(AppAnimation.standardSpring, value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.96 : 1)
    }
}

private struct ClosetProfileAvatar: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url, showsLoadingIndicator: false) { image in
                    image.resizable().scaledToFill()
                }
            } else {
                placeholder
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.black.opacity(0.14))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.36))
            }
    }
}
