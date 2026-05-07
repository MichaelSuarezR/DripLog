import SwiftUI

struct ProfileTab: View {
    let user: AppUser
    let outfitPhotos: [OutfitPhoto]
    let onLogOut: () -> Void
    let onEditOutfit: (OutfitPhoto) -> Void
    let onAskForSuggestions: () -> Void

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
                    closetHeader
                    outfitsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $isFilterPresented) {
                ClosetFilterView(filters: $filters)
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
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(0.14))
                    .frame(width: 22, height: 22)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(0.14))
                    .frame(width: 22, height: 22)

                Menu {
                    Button("Log Out", role: .destructive, action: onLogOut)
                } label: {
                    Circle()
                        .fill(Color.black.opacity(0.14))
                        .frame(width: 30, height: 30)
                }
            }
        }
        .padding(.top, 12)
    }

    private var inspirationBanner: some View {
        Button {
            onAskForSuggestions()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.16), in: Circle())

                Text("don't know what to wear?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.70, green: 0.68, blue: 0.69),
                        Color(red: 0.62, green: 0.60, blue: 0.61)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
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
            if filteredOutfits.isEmpty {
                ForEach(0..<6, id: \.self) { _ in
                    closetPlaceholderCard
                }
            } else {
                ForEach(filteredOutfits) { photo in
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: photo.imageURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Color.black.opacity(0.08)
                                }
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
                                    .foregroundStyle(.black)
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
}