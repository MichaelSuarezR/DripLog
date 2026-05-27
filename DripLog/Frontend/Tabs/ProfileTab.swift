import SwiftUI

struct ProfileTab: View {
    let user: AppUser
    let outfitPhotos: [OutfitPhoto]
    let isLoadingOutfits: Bool
    let errorMessage: String?
    let onLogOut: () -> Void
    let onEditOutfit: (OutfitPhoto) -> Void
    let onAskForSuggestions: () -> Void
    let onProfileTapped: () -> Void
    let onLoadOutfits: () async -> Void
    let onRefreshOutfits: () async -> Void

    @State private var isFilterPresented = false
    @State private var filters = ClosetFilters()
    @State private var profilePhotoURL: URL?
    @State private var authService: AuthServicing?

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
                    closetHeader
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    outfitsSection
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
                    await loadProfilePhoto()
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
        }
    }

    private var headerRow: some View {
        HStack(alignment: .bottom) {
            Text("Hello, \(displayName)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.black)

            Spacer()

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(0.14))
                    .frame(width: 22, height: 22)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(0.14))
                    .frame(width: 22, height: 22)

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
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))

                Text("Generate Outfit")
                    .font(AppFont.uiBold(size: 16))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                AIRainbowBorderView(cornerRadius: 14, lineWidth: 2.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                ForEach(0..<6, id: \.self) { _ in
                    closetPlaceholderCard
                }
            } else if filteredOutfits.isEmpty {
                ForEach(0..<6, id: \.self) { _ in
                    closetPlaceholderCard
                }
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

                        if !photo.tags.isEmpty {
                            Text(photo.tags.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.black.opacity(0.72))
                                .lineLimit(1)
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

            if !filters.categoryMatches(tags: normalizedTags) {
                return false
            }

            if !filters.weather.isEmpty && normalizedTags.isDisjoint(with: filters.weatherNormalized) {
                return false
            }

            if !filters.occasion.isEmpty && normalizedTags.isDisjoint(with: filters.occasionNormalized) {
                return false
            }

            if !filters.colors.isEmpty && normalizedTags.isDisjoint(with: filters.colorsNormalized) {
                return false
            }

            if !filters.custom.isEmpty && normalizedTags.isDisjoint(with: filters.customNormalized) {
                return false
            }

            return true
        }
    }

    private func loadProfilePhoto() async {
        do {
            profilePhotoURL = try await service().fetchProfilePhotoURL(for: user.id)
        } catch {
            profilePhotoURL = nil
        }
    }

    private func service() throws -> AuthServicing {
        if let authService { return authService }
        let createdService = try SupabaseAuthService()
        authService = createdService
        return createdService
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
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
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
