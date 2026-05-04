//
//  HomeView.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import Combine

struct HomeView: View {
    let user: AppUser
    let onLogOut: () -> Void

    @State private var selectedTab: AppTab = .feed
    @State private var pendingOutfitDraft: PendingOutfitDraft?
    @State private var editingOutfit: OutfitPhoto?
    @State private var outfitPhotos: [OutfitPhoto] = []
    @State private var outfitErrorMessage: String?
    @State private var didLoadOutfits = false
    @State private var outfitService: OutfitServicing?
    @State private var suggestionService: SuggestionServicing?
    @State private var isSuggestionsPresented = false
    @State private var isLoadingSuggestions = false
    @State private var suggestions: OutfitSuggestions?
    @State private var suggestionErrorMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTabView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
        }
        .task {
            await loadOutfitsIfNeeded()
        }
        .fullScreenCover(item: $pendingOutfitDraft) { draft in
            OutfitUploadTaggingView(
                image: draft.image,
                onCancel: {
                    pendingOutfitDraft = nil
                },
                onSave: { metadata in
                    let photo = try await service().uploadOutfit(draft.image, metadata: metadata, for: user.id)
                    outfitPhotos.insert(photo, at: 0)
                    pendingOutfitDraft = nil
                    selectedTab = .closet
                }
            )
        }
        .fullScreenCover(item: $editingOutfit) { photo in
            OutfitEditView(
                photo: photo,
                onClose: { metadata in
                    await updateOutfitMetadata(metadata, for: photo.id)
                },
                onDelete: {
                    await deleteOutfit(photo)
                }
            )
        }
        .fullScreenCover(isPresented: $isSuggestionsPresented) {
            SuggestionsView(
                suggestions: suggestions,
                isLoading: isLoadingSuggestions,
                errorMessage: suggestionErrorMessage,
                onClose: {
                    isSuggestionsPresented = false
                },
                onRetry: prepareSuggestions
            )
        }
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .closet:
            ProfileTab(
                user: user,
                outfitPhotos: outfitPhotos,
                onLogOut: onLogOut,
                onEditOutfit: { editingOutfit = $0 },
                onAskForSuggestions: prepareSuggestions
            )
        case .add:
            CreateTab(
                isUploading: false,
                errorMessage: outfitErrorMessage,
                onCapture: prepareOutfit
            )
        case .feed:
            HomeTab(user: user)
        }
    }

    private func loadOutfitsIfNeeded() async {
        guard !didLoadOutfits else { return }
        didLoadOutfits = true

        do {
            outfitPhotos = try await service().fetchOutfits(for: user.id)
        } catch {
            outfitErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not load saved outfits."
        }
    }

    private func prepareOutfit(_ image: UIImage) {
        outfitErrorMessage = nil
        pendingOutfitDraft = PendingOutfitDraft(image: image)
    }

    private func updateOutfitMetadata(_ metadata: OutfitMetadata, for outfitID: UUID) async {
        do {
            try await service().updateOutfitMetadata(metadata, for: outfitID)

            if let index = outfitPhotos.firstIndex(where: { $0.id == outfitID }) {
                let existing = outfitPhotos[index]
                outfitPhotos[index] = OutfitPhoto(
                    id: existing.id,
                    imagePath: existing.imagePath,
                    image: existing.image,
                    tags: metadata.allTags,
                    customTags: metadata.customTags,
                    categories: metadata.categories,
                    weather: metadata.weather,
                    occasion: metadata.occasion,
                    colors: metadata.colors
                )
            }
        } catch {
            outfitErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not update outfit details."
        }
    }

    private func deleteOutfit(_ photo: OutfitPhoto) async {
        do {
            try await service().deleteOutfit(photo)
            outfitPhotos.removeAll { $0.id == photo.id }
            editingOutfit = nil
        } catch {
            outfitErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not delete outfit."
        }
    }

    private func prepareSuggestions() {
        isSuggestionsPresented = true
        isLoadingSuggestions = true
        suggestionErrorMessage = nil
        suggestions = nil

        Task {
            do {
                suggestions = try await suggestionProvider().makeSuggestions(for: user, outfitPhotos: outfitPhotos)
            } catch {
                suggestionErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not build suggestions right now."
            }

            isLoadingSuggestions = false
        }
    }

    private func service() throws -> OutfitServicing {
        if let outfitService {
            return outfitService
        }

        let createdService = try SupabaseOutfitService()
        outfitService = createdService
        return createdService
    }

    private func suggestionProvider() throws -> SuggestionServicing {
        if let suggestionService {
            return suggestionService
        }

        let createdService = try SupabaseSuggestionService()
        suggestionService = createdService
        return createdService
    }
}

private enum AppTab {
    case closet
    case add
    case feed
}

private struct PendingOutfitDraft: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    private let barWidth: CGFloat = 334
    private let barHeight: CGFloat = 59

    var body: some View {
        ZStack(alignment: .top) {
            Image("CustomTabBarBackground")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: barWidth, height: barHeight)

            HStack {
                tabButton(imageName: "ClosetTabIcon", tab: .closet)
                Spacer()
                tabButton(imageName: "FeedTabIcon", tab: .feed)
            }
            .padding(.horizontal, 52)
            .frame(width: barWidth, height: barHeight)

            Button {
                selectedTab = .add
            } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image("AddTabIcon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(iconColor(for: .add))
                    }
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            }
            .offset(y: -6)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(alignment: .bottom) {
            Color.white
                .frame(height: 24)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(imageName: String, tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: tab == .closet ? 18 : 21, height: 18)
                .foregroundStyle(iconColor(for: tab))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconColor(for tab: AppTab) -> Color {
        selectedTab == tab
            ? Color(red: 0.08, green: 0.34, blue: 0.27)
            : Color(red: 0.42, green: 0.45, blue: 0.50)
    }
}

private struct HomeTab: View {
    let user: AppUser

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 50, height: 50)
                    
                    Text("welcome, \(user.name.isEmpty ? "matthew" : user.name.lowercased())!")
                        .font(.title3.weight(.semibold))
                    
                    Text("my friends")
                        .font(.headline)
                    
                    HStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(Color.black.opacity(0.12))
                                .frame(width: 34, height: 34)
                        }
                    }
                    
                    Text("your feed")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    HStack(spacing: 12) {
                        FeedFilterChip(title: "recent", isActive: true)
                        FeedFilterChip(title: "friends only")
                        FeedFilterChip(title: "saved")
                    }
                    .padding(.bottom, 2)
                    
                    FeedPostPlaceholder(author: "vicky", followTitle: "following", showsTags: true)
                    FeedPostPlaceholder(author: "cecile", followTitle: "follow", showsTags: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct FeedFilterChip: View {
    let title: String
    var isActive: Bool = false
    
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 29)
            .background(
                isActive ? Color.black.opacity(0.25) : Color.black.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 14.5, style: .continuous)
            )
    }
}

private struct FeedPostPlaceholder: View {
    let author: String
    let followTitle: String
    let showsTags: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 33, height: 33)
                
                Text(author)
                    .font(.title3.weight(.semibold))
                
                Spacer()
                
                Text(followTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 120, height: 33)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
                .frame(height: 373)
            
            HStack {
                Text("OOTD")
                    .font(.headline.weight(.semibold))
                Spacer()
                Image(systemName: "message")
                Image(systemName: "heart")
                Image(systemName: "bookmark")
            }
            .font(.title3)
            
            Text("april 20, 2026")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("sacccacsasakccndndpwqjdpqwjdwjqpdjwqdwqdqwdqwndwqdd")
                .font(.caption2)
                .lineLimit(2)
            
            if showsTags {
                HStack(spacing: 8) {
                    Text("Brown Leather Belt")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    Text("Black Top")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(.bottom, 10)
    }
}

private struct CreateTab: View {
    let isUploading: Bool
    let errorMessage: String?
    let onCapture: (UIImage) -> Void

    @State private var isCameraPresented = false
    @State private var cameraErrorMessage: String?
    @State private var capturedImage: UIImage?
    @State private var suppressAutoPresent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()

                if isUploading {
                    ProgressView("Uploading outfit photo...")
                }

                if let cameraErrorMessage {
                    Text(cameraErrorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: presentCamera) {
                    Label(isUploading ? "Saving..." : "Open Camera", systemImage: "camera")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color(red: 0.08, green: 0.34, blue: 0.27), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .disabled(isUploading)
                .opacity(isUploading ? 0.7 : 1)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Add")
            .onAppear {
                guard !suppressAutoPresent else {
                    suppressAutoPresent = false
                    return
                }

                presentCamera()
            }
            .fullScreenCover(isPresented: $isCameraPresented, onDismiss: handleCameraDismissed) {
                OutfitCameraView { image in
                    capturedImage = image
                    suppressAutoPresent = true
                    isCameraPresented = false
                }
            }
        }
    }

    private func presentCamera() {
        guard !isUploading else { return }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraErrorMessage = "Camera is not available on this device or simulator."
            return
        }

        cameraErrorMessage = nil
        isCameraPresented = true
    }

    private func handleCameraDismissed() {
        guard let capturedImage else { return }
        let image = capturedImage
        self.capturedImage = nil
        onCapture(image)
    }
}

private struct ProfileTab: View {
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
                            Image(uiImage: photo.image)
                                .resizable()
                                .scaledToFill()
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

private struct SuggestionsView: View {
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
                                        image: suggestions.leftOutfit.image,
                                        title: "Your Closet",
                                        detail: cardDetail(for: suggestions.leftOutfit.tags)
                                    )

                                    inspirationSuggestionCard(look: suggestions.centerInspiration)

                                    closetSuggestionCard(
                                        image: suggestions.rightOutfit.image,
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

    private func closetSuggestionCard(image: UIImage, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
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
                case .failure(_):
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
                        .overlay {
                            ProgressView()
                        }
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

    private func cardDetail(for tags: [String]) -> String {
        let trimmed = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if trimmed.isEmpty {
            return "A clean option from your closet."
        }

        return trimmed.prefix(3).joined(separator: " • ")
    }
}

private struct ClosetFilterView: View {
    @Binding var filters: ClosetFilters
    @Environment(\.dismiss) private var dismiss

    @State private var expandedSections: Set<ClosetFilterSection> = [
        .rating,
        .categories,
        .weather
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    filterSection(
                        title: "Rating",
                        placeholder: "Give a rating",
                        section: .rating
                    ) {
                        ratingRow
                    }

                    filterSection(
                        title: "Categories",
                        placeholder: "Choose a category",
                        section: .categories
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(ClosetCategoryGroup.allCases) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    categoryGroupChip(group.title, isSelected: true)
                                    chipGrid(items: group.items, selected: binding(for: group))
                                }
                            }

                            clearButton {
                                filters.clearCategories()
                            }
                        }
                    }

                    filterSection(
                        title: "Weather",
                        placeholder: "Choose the weather",
                        section: .weather
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            chipGrid(items: ClosetFilters.weatherOptions, selected: $filters.weather)
                            clearButton {
                                filters.weather.removeAll()
                            }
                        }
                    }

                    filterSection(
                        title: "Occasion",
                        placeholder: "Choose the occassion",
                        section: .occasion
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            chipGrid(items: ClosetFilters.occasionOptions, selected: $filters.occasion)
                            clearButton {
                                filters.occasion.removeAll()
                            }
                        }
                    }

                    filterSection(
                        title: "Colors",
                        placeholder: "Choose the colors",
                        section: .colors
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            chipGrid(items: ClosetFilters.colorOptions, selected: $filters.colors)
                            clearButton {
                                filters.colors.removeAll()
                            }
                        }
                    }

                    filterSection(
                        title: "Custom",
                        placeholder: "Choose your custom tags",
                        section: .custom
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            chipGrid(items: filters.customSuggestions, selected: $filters.custom)
                            clearButton {
                                filters.custom.removeAll()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
            .background(Color.white)
        }
    }

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .frame(height: 56)

            Text("Filter")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.black)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundStyle(.black)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    filters.rating = filters.rating == value ? nil : value
                } label: {
                    Image(systemName: value <= (filters.rating ?? 0) ? "star.fill" : "star.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(value <= (filters.rating ?? 0) ? Color(red: 1.0, green: 0.84, blue: 0.24) : Color.black.opacity(0.18))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func filterSection<Content: View>(
        title: String,
        placeholder: String,
        section: ClosetFilterSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                toggle(section)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)

                    Spacer()

                    Text(sectionSummary(for: section).isEmpty ? placeholder : sectionSummary(for: section))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(sectionSummary(for: section).isEmpty ? Color.black.opacity(0.35) : .black)

                    Image(systemName: expandedSections.contains(section) ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)
                }
            }
            .buttonStyle(.plain)

            if expandedSections.contains(section) {
                content()
                    .padding(.leading, 10)
            }
        }
    }

    private func chipGrid(items: [String], selected: Binding<Set<String>>) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 64, maximum: 132), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.wrappedValue.contains(item)

                Button {
                    if isSelected {
                        selected.wrappedValue.remove(item)
                    } else {
                        selected.wrappedValue.insert(item)
                    }
                } label: {
                    Text(item)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(isSelected ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func categoryGroupChip(_ title: String, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
            }

            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func clearButton(action: @escaping () -> Void) -> some View {
        Button("Clear all", action: action)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.black.opacity(0.35))
            .padding(.horizontal, 14)
            .frame(height: 24)
            .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .buttonStyle(.plain)
    }

    private func toggle(_ section: ClosetFilterSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    private func sectionSummary(for section: ClosetFilterSection) -> String {
        switch section {
        case .rating:
            if let rating = filters.rating {
                return "\(rating) stars"
            }
            return ""
        case .categories:
            let count = filters.categorySelectionCount
            return count == 0 ? "" : "\(count) selected"
        case .weather:
            return summaryText(for: filters.weather)
        case .occasion:
            return summaryText(for: filters.occasion)
        case .colors:
            return summaryText(for: filters.colors)
        case .custom:
            return summaryText(for: filters.custom)
        case .visibility:
            return ""
        }
    }

    private func summaryText(for set: Set<String>) -> String {
        guard !set.isEmpty else { return "" }
        if set.count == 1, let value = set.first {
            return value
        }
        return "\(set.count) selected"
    }

    private func binding(for group: ClosetCategoryGroup) -> Binding<Set<String>> {
        switch group {
        case .tops:
            return $filters.topCategories
        case .bottoms:
            return $filters.bottomCategories
        case .outerwear:
            return $filters.outerwearCategories
        case .shoes:
            return $filters.shoesCategories
        case .accessories:
            return $filters.accessoriesCategories
        }
    }
}

private struct OutfitEditView: View {
    let photo: OutfitPhoto
    let onClose: (OutfitMetadata) async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var filters: ClosetFilters
    @State private var notes = ""
    @State private var visibility: OutfitVisibility = .privateProfile
    @State private var expandedSections: Set<ClosetFilterSection> = []
    @State private var isSaving = false
    @State private var isDeleting = false

    init(
        photo: OutfitPhoto,
        onClose: @escaping (OutfitMetadata) async -> Void,
        onDelete: @escaping () async -> Void
    ) {
        self.photo = photo
        self.onClose = onClose
        self.onDelete = onDelete
        _filters = State(initialValue: ClosetFilters(
            metadata: OutfitMetadata(
                customTags: photo.customTags,
                categories: photo.categories,
                weather: photo.weather,
                occasion: photo.occasion,
                colors: photo.colors
            )
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    editorHeader

                    editSection(title: "Rating", placeholder: "Give a rating", section: .rating) {
                        ratingRow
                    }

                    editSection(title: "Category", placeholder: "Choose a category", section: .categories) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(ClosetCategoryGroup.allCases) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    editorCategoryGroupChip(group.title, isSelected: true)
                                    editorChipGrid(items: group.items, selected: binding(for: group))
                                }
                            }
                        }
                    }

                    editSection(title: "Weather", placeholder: "Choose the weather", section: .weather) {
                        editorChipGrid(items: ClosetFilters.weatherOptions, selected: $filters.weather)
                    }

                    editSection(title: "Occasion", placeholder: "Choose the occassion", section: .occasion) {
                        editorChipGrid(items: ClosetFilters.occasionOptions, selected: $filters.occasion)
                    }

                    editSection(title: "Colors", placeholder: "Choose the colors", section: .colors) {
                        editorChipGrid(items: ClosetFilters.colorOptions, selected: $filters.colors)
                    }

                    editSection(title: "Custom", placeholder: "Choose your custom tags", section: .custom) {
                        editorChipGrid(items: filters.customSuggestions, selected: $filters.custom)
                    }

                    Divider()
                        .overlay(Color.black.opacity(0.4))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Additional Images")
                            .font(.title3.weight(.semibold))

                        Button {
                        } label: {
                            RoundedRectangle(cornerRadius: 0, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [2.5]))
                                .fill(Color.clear)
                                .frame(width: 88, height: 88)
                                .overlay {
                                    VStack(spacing: 4) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 20))
                                        Text("Add")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.black.opacity(0.55))
                                }
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .overlay(Color.black.opacity(0.4))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.title3.weight(.semibold))

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.black.opacity(0.10))
                                .frame(height: 138)

                            TextEditor(text: $notes)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(height: 138)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)

                            if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Write here")
                                    .font(.subheadline)
                                    .foregroundStyle(.black.opacity(0.55))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 14)
                            }
                        }
                    }

                    Divider()
                        .overlay(Color.black.opacity(0.4))

                    editSection(title: "Visibility", placeholder: "Choose your visibility", section: .visibility) {
                        editorChipGrid(items: OutfitVisibility.allCases.map(\.title), selected: visibilityBinding)
                    }

                    Button(role: .destructive) {
                        deleteOutfit()
                    } label: {
                        Text(isDeleting ? "Deleting..." : "Delete outfit")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(width: 210, height: 34)
                            .background(Color.black.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .disabled(isDeleting || isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 32)
            }
            .background(Color.white)
        }
    }

    private var editorHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .frame(height: 56)

            Text("Edit Tags")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.black)

            HStack {
                Button {
                    saveAndDismiss()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundStyle(.black)
                }
                .disabled(isSaving || isDeleting)

                Spacer()
            }
            .padding(.horizontal, 10)
        }
    }

    @ViewBuilder
    private func editSection<Content: View>(
        title: String,
        placeholder: String,
        section: ClosetFilterSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                toggle(section)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)

                    Spacer()

                    Text(editorSummary(for: section).isEmpty ? placeholder : editorSummary(for: section))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(editorSummary(for: section).isEmpty ? Color.black.opacity(0.35) : .black)

                    Image(systemName: expandedSections.contains(section) ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)
                }
            }
            .buttonStyle(.plain)

            if expandedSections.contains(section) {
                content()
                    .padding(.leading, 10)
            }
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    filters.rating = filters.rating == value ? nil : value
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(value <= (filters.rating ?? 0) ? Color(red: 1.0, green: 0.84, blue: 0.24) : Color.black.opacity(0.18))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func editorChipGrid(items: [String], selected: Binding<Set<String>>) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 64, maximum: 132), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.wrappedValue.contains(item)

                Button {
                    if isSelected {
                        selected.wrappedValue.remove(item)
                    } else {
                        selected.wrappedValue.insert(item)
                    }
                } label: {
                    Text(item)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(isSelected ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func editorCategoryGroupChip(_ title: String, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
            }

            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var visibilityBinding: Binding<Set<String>> {
        Binding(
            get: { [visibility.title] },
            set: { values in
                if let value = values.first, let selected = OutfitVisibility(title: value) {
                    visibility = selected
                }
            }
        )
    }

    private func binding(for group: ClosetCategoryGroup) -> Binding<Set<String>> {
        switch group {
        case .tops:
            return $filters.topCategories
        case .bottoms:
            return $filters.bottomCategories
        case .outerwear:
            return $filters.outerwearCategories
        case .shoes:
            return $filters.shoesCategories
        case .accessories:
            return $filters.accessoriesCategories
        }
    }

    private func toggle(_ section: ClosetFilterSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    private func editorSummary(for section: ClosetFilterSection) -> String {
        switch section {
        case .rating:
            if let rating = filters.rating {
                return "\(rating) stars"
            }
            return ""
        case .categories:
            let count = filters.categorySelectionCount
            return count == 0 ? "" : "\(count) selected"
        case .weather:
            return selectionSummary(for: filters.weather)
        case .occasion:
            return selectionSummary(for: filters.occasion)
        case .colors:
            return selectionSummary(for: filters.colors)
        case .custom:
            return selectionSummary(for: filters.custom)
        case .visibility:
            return visibility.title
        }
    }

    private func selectionSummary(for values: Set<String>) -> String {
        guard !values.isEmpty else { return "" }
        if values.count == 1, let first = values.first {
            return first
        }
        return "\(values.count) selected"
    }

    private func saveAndDismiss() {
        guard !isSaving, !isDeleting else { return }

        Task {
            isSaving = true
            await onClose(filters.metadata)
            isSaving = false
            dismiss()
        }
    }

    private func deleteOutfit() {
        guard !isDeleting, !isSaving else { return }

        Task {
            isDeleting = true
            await onDelete()
            isDeleting = false
            dismiss()
        }
    }
}

private enum ClosetFilterSection: Hashable {
    case rating
    case categories
    case weather
    case occasion
    case colors
    case custom
    case visibility
}

private enum ClosetCategoryGroup: String, CaseIterable, Identifiable {
    case tops
    case bottoms
    case outerwear
    case shoes
    case accessories

    var id: String { rawValue }

    var title: String { rawValue }

    var items: [String] {
        switch self {
        case .tops:
            return ["t-shirt", "zip-up", "tank top", "crop top", "button-up", "hoodie", "long-sleeve", "sweater", "polo", "cardigan", "flannel", "blouse"]
        case .bottoms:
            return ["jeans", "shorts", "leggings", "trousers", "joggers", "skirt", "dress pants", "cargos", "sweatpants", "slacks", "jorts", "dress"]
        case .outerwear:
            return ["coat", "trench coat", "jacket", "fur coat", "cardigan", "blazer", "puffer jacket", "leather jacket", "windbreaker", "overcoat", "zip-up", "sweater"]
        case .shoes:
            return ["running shoes", "boots", "sandals", "dress shoes", "loafers", "high heels", "slides", "sneakers"]
        case .accessories:
            return ["hat", "scarf", "glasses", "watch", "handbag", "necklace", "earrings", "belt", "bracelet", "rings", "gloves", "sunglasses"]
        }
    }
}

private struct ClosetFilters {
    var rating: Int?
    var topCategories: Set<String> = []
    var bottomCategories: Set<String> = []
    var outerwearCategories: Set<String> = []
    var shoesCategories: Set<String> = []
    var accessoriesCategories: Set<String> = []
    var weather: Set<String> = []
    var occasion: Set<String> = []
    var colors: Set<String> = []
    var custom: Set<String> = []

    static let weatherOptions = ["sunny", "cold", "rainy", "snowy", "humid", "warm", "hot", "windy"]
    static let occasionOptions = ["casual", "formal", "biz-casual", "semi-formal", "going out", "outdoors", "date night", "concert", "at home", "professional", "beach", "special event"]
    static let colorOptions = ["black", "white", "gray", "brown", "blue", "green", "red", "pink", "purple", "yellow", "orange", "tan"]

    var customSuggestions: [String] {
        ["vintage", "streetwear", "minimal", "layered", "gym", "cozy", "monochrome", "silver jewelry", "gold jewelry", "baggy"]
    }

    init() {}

    init(tags: [String]) {
        for tag in tags {
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = normalized.lowercased()

            if Self.weatherOptions.contains(lowercased) {
                weather.insert(lowercased)
            } else if Self.occasionOptions.contains(lowercased) {
                occasion.insert(lowercased)
            } else if Self.colorOptions.contains(lowercased) {
                colors.insert(lowercased)
            } else if ClosetCategoryGroup.tops.items.contains(lowercased) {
                topCategories.insert(lowercased)
            } else if ClosetCategoryGroup.bottoms.items.contains(lowercased) {
                bottomCategories.insert(lowercased)
            } else if ClosetCategoryGroup.outerwear.items.contains(lowercased) {
                outerwearCategories.insert(lowercased)
            } else if ClosetCategoryGroup.shoes.items.contains(lowercased) {
                shoesCategories.insert(lowercased)
            } else if ClosetCategoryGroup.accessories.items.contains(lowercased) {
                accessoriesCategories.insert(lowercased)
            } else {
                custom.insert(normalized)
            }
        }
    }

    init(metadata: OutfitMetadata) {
        topCategories = Set(metadata.categories.filter { ClosetCategoryGroup.tops.items.contains($0.lowercased()) }.map { $0.lowercased() })
        bottomCategories = Set(metadata.categories.filter { ClosetCategoryGroup.bottoms.items.contains($0.lowercased()) }.map { $0.lowercased() })
        outerwearCategories = Set(metadata.categories.filter { ClosetCategoryGroup.outerwear.items.contains($0.lowercased()) }.map { $0.lowercased() })
        shoesCategories = Set(metadata.categories.filter { ClosetCategoryGroup.shoes.items.contains($0.lowercased()) }.map { $0.lowercased() })
        accessoriesCategories = Set(metadata.categories.filter { ClosetCategoryGroup.accessories.items.contains($0.lowercased()) }.map { $0.lowercased() })
        weather = Set(metadata.weather.map { $0.lowercased() })
        occasion = Set(metadata.occasion.map { $0.lowercased() })
        colors = Set(metadata.colors.map { $0.lowercased() })
        custom = Set(metadata.customTags)
    }

    var hasActiveSelections: Bool {
        rating != nil ||
        categorySelectionCount > 0 ||
        !weather.isEmpty ||
        !occasion.isEmpty ||
        !colors.isEmpty ||
        !custom.isEmpty
    }

    var categorySelectionCount: Int {
        topCategories.count +
        bottomCategories.count +
        outerwearCategories.count +
        shoesCategories.count +
        accessoriesCategories.count
    }

    var weatherNormalized: Set<String> {
        Set(weather.map { $0.lowercased() })
    }

    var occasionNormalized: Set<String> {
        Set(occasion.map { $0.lowercased() })
    }

    var colorsNormalized: Set<String> {
        Set(colors.map { $0.lowercased() })
    }

    var customNormalized: Set<String> {
        Set(custom.map { $0.lowercased() })
    }

    var combinedTags: [String] {
        var orderedTags: [String] = []

        orderedTags.append(contentsOf: ClosetCategoryGroup.tops.items.filter { topCategories.contains($0) })
        orderedTags.append(contentsOf: ClosetCategoryGroup.bottoms.items.filter { bottomCategories.contains($0) })
        orderedTags.append(contentsOf: ClosetCategoryGroup.outerwear.items.filter { outerwearCategories.contains($0) })
        orderedTags.append(contentsOf: ClosetCategoryGroup.shoes.items.filter { shoesCategories.contains($0) })
        orderedTags.append(contentsOf: ClosetCategoryGroup.accessories.items.filter { accessoriesCategories.contains($0) })
        orderedTags.append(contentsOf: Self.weatherOptions.filter { weather.contains($0) })
        orderedTags.append(contentsOf: Self.occasionOptions.filter { occasion.contains($0) })
        orderedTags.append(contentsOf: Self.colorOptions.filter { colors.contains($0) })
        orderedTags.append(contentsOf: custom.sorted())

        return Array(NSOrderedSet(array: orderedTags)) as? [String] ?? orderedTags
    }

    var metadata: OutfitMetadata {
        OutfitMetadata(
            customTags: custom.sorted(),
            categories: selectedCategories,
            weather: Self.weatherOptions.filter { weather.contains($0) },
            occasion: Self.occasionOptions.filter { occasion.contains($0) },
            colors: Self.colorOptions.filter { colors.contains($0) }
        )
    }

    var selectedCategories: [String] {
        var orderedCategories: [String] = []
        orderedCategories.append(contentsOf: ClosetCategoryGroup.tops.items.filter { topCategories.contains($0) })
        orderedCategories.append(contentsOf: ClosetCategoryGroup.bottoms.items.filter { bottomCategories.contains($0) })
        orderedCategories.append(contentsOf: ClosetCategoryGroup.outerwear.items.filter { outerwearCategories.contains($0) })
        orderedCategories.append(contentsOf: ClosetCategoryGroup.shoes.items.filter { shoesCategories.contains($0) })
        orderedCategories.append(contentsOf: ClosetCategoryGroup.accessories.items.filter { accessoriesCategories.contains($0) })
        return Array(NSOrderedSet(array: orderedCategories)) as? [String] ?? orderedCategories
    }

    func categoryMatches(tags: Set<String>) -> Bool {
        let groups: [Set<String>] = [
            Set(topCategories.map { $0.lowercased() }),
            Set(bottomCategories.map { $0.lowercased() }),
            Set(outerwearCategories.map { $0.lowercased() }),
            Set(shoesCategories.map { $0.lowercased() }),
            Set(accessoriesCategories.map { $0.lowercased() })
        ]

        return groups.allSatisfy { selection in
            selection.isEmpty || !tags.isDisjoint(with: selection)
        }
    }

    mutating func clearCategories() {
        topCategories.removeAll()
        bottomCategories.removeAll()
        outerwearCategories.removeAll()
        shoesCategories.removeAll()
        accessoriesCategories.removeAll()
    }
}

private enum OutfitVisibility: CaseIterable {
    case privateProfile
    case friends
    case publicProfile

    var title: String {
        switch self {
        case .privateProfile:
            return "private"
        case .friends:
            return "friends"
        case .publicProfile:
            return "public"
        }
    }

    init?(title: String) {
        switch title {
        case "private":
            self = .privateProfile
        case "friends":
            self = .friends
        case "public":
            self = .publicProfile
        default:
            return nil
        }
    }
}

private struct OutfitUploadTaggingView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onSave: (OutfitMetadata) async throws -> Void

    @State private var filters = ClosetFilters()
    @State private var expandedSections: Set<ClosetFilterSection> = []
    @State private var tagInput = ""
    @State private var isSaving = false
    @State private var saveError: String?

    private let suggestedTags = [
        "Black Top",
        "Dark Blue Jeans",
        "Red Scarf",
        "Flared Leggings",
        "White Sneakers",
        "Brown Leather Belt",
        "Black Hoodie",
        "Blue Denim Jacket",
        "Gray Sweatpants",
        "Gold Jewelry"
    ]

    private var filteredSuggestions: [String] {
        let normalizedInput = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedTags = Array(filters.custom)

        if normalizedInput.isEmpty {
            return suggestedTags.filter { !selectedTags.contains($0) }
        }

        return suggestedTags.filter {
            !selectedTags.contains($0) && $0.localizedCaseInsensitiveContains(normalizedInput)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    promptRow
                    tagChips
                    metadataSections
                    Divider()
                        .padding(.top, 18)
                        .padding(.bottom, 16)

                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(filteredSuggestions, id: \.self) { tag in
                            Button(action: {
                                addTag(tag)
                            }) {
                                Text(tag)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.white)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.title3)
                    .foregroundStyle(.black)
                    .disabled(isSaving)
                    .opacity(isSaving ? 0.4 : 1)

                Spacer()

                Text("Outfit Upload")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black)

                Spacer()

                Button(isSaving ? "Saving..." : "Save") {
                    saveOutfit()
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black)
                .disabled(isSaving)
                .opacity(isSaving ? 0.4 : 1)
            }

            if let saveError {
                Text(saveError)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 22)
    }

    private var promptRow: some View {
        HStack(alignment: .top, spacing: 16) {
            TextField("What are you wearing?", text: $tagInput)
                .font(.title3)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit {
                    addTag(tagInput)
                }

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipped()
        }
    }

    @ViewBuilder
    private var tagChips: some View {
        let selectedTags = Array(filters.custom).sorted()
        if !selectedTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedTags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text(tag)
                                .font(.subheadline.weight(.medium))
                            Button {
                                filters.custom.remove(tag)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.systemGray6), in: Capsule())
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private var metadataSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            uploadSection(title: "Category", placeholder: "Choose categories", section: .categories) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(ClosetCategoryGroup.allCases) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            categoryGroupChip(group.title, isSelected: true)
                            chipGrid(items: group.items, selected: binding(for: group))
                        }
                    }
                }
            }

            uploadSection(title: "Weather", placeholder: "Choose the weather", section: .weather) {
                chipGrid(items: ClosetFilters.weatherOptions, selected: $filters.weather)
            }

            uploadSection(title: "Occasion", placeholder: "Choose the occasion", section: .occasion) {
                chipGrid(items: ClosetFilters.occasionOptions, selected: $filters.occasion)
            }

            uploadSection(title: "Colors", placeholder: "Choose the colors", section: .colors) {
                chipGrid(items: ClosetFilters.colorOptions, selected: $filters.colors)
            }
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private func uploadSection<Content: View>(
        title: String,
        placeholder: String,
        section: ClosetFilterSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                toggle(section)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)

                    Spacer()

                    Text(uploadSummary(for: section).isEmpty ? placeholder : uploadSummary(for: section))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(uploadSummary(for: section).isEmpty ? Color.black.opacity(0.35) : .black)

                    Image(systemName: expandedSections.contains(section) ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)
                }
            }
            .buttonStyle(.plain)

            if expandedSections.contains(section) {
                content()
            }
        }
    }

    private func chipGrid(items: [String], selected: Binding<Set<String>>) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 64, maximum: 132), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.wrappedValue.contains(item)

                Button {
                    if isSelected {
                        selected.wrappedValue.remove(item)
                    } else {
                        selected.wrappedValue.insert(item)
                    }
                } label: {
                    Text(item)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(isSelected ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func categoryGroupChip(_ title: String, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
            }

            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func binding(for group: ClosetCategoryGroup) -> Binding<Set<String>> {
        switch group {
        case .tops:
            return $filters.topCategories
        case .bottoms:
            return $filters.bottomCategories
        case .outerwear:
            return $filters.outerwearCategories
        case .shoes:
            return $filters.shoesCategories
        case .accessories:
            return $filters.accessoriesCategories
        }
    }

    private func toggle(_ section: ClosetFilterSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    private func uploadSummary(for section: ClosetFilterSection) -> String {
        switch section {
        case .categories:
            let count = filters.categorySelectionCount
            return count == 0 ? "" : "\(count) selected"
        case .weather:
            return summaryText(for: filters.weather)
        case .occasion:
            return summaryText(for: filters.occasion)
        case .colors:
            return summaryText(for: filters.colors)
        case .custom:
            return summaryText(for: filters.custom)
        case .rating, .visibility:
            return ""
        }
    }

    private func summaryText(for set: Set<String>) -> String {
        guard !set.isEmpty else { return "" }
        if set.count == 1, let value = set.first {
            return value
        }
        return "\(set.count) selected"
    }

    private func addTag(_ rawTag: String) {
        let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        guard !filters.custom.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else {
            tagInput = ""
            return
        }

        filters.custom.insert(tag)
        tagInput = ""
    }

    private func saveOutfit() {
        guard !isSaving else { return }

        let trimmedInput = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInput.isEmpty,
           !filters.custom.contains(where: { $0.caseInsensitiveCompare(trimmedInput) == .orderedSame }) {
            filters.custom.insert(trimmedInput)
        }

        let metadata = filters.metadata

        Task {
            isSaving = true
            saveError = nil
            defer { isSaving = false }

            do {
                try await onSave(metadata)
            } catch {
                saveError = (error as? LocalizedError)?.errorDescription ?? "Could not save outfit photo."
            }
        }
    }
}

private struct OutfitCameraView: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraController = CameraSessionController()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoadingLibraryImage = false
    @State private var isFlashEnabled = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraController.session)
                .ignoresSafeArea()
                .overlay {
                    if !cameraController.isReady {
                        Color.black
                            .overlay {
                                if let errorMessage = cameraController.errorMessage {
                                    Text(errorMessage)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(24)
                                } else {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                    }
                }

            VStack {
                HStack {
                    circularControlButton(systemImage: "chevron.left", action: { dismiss() })
                    Spacer()
                    circularControlButton(systemImage: "ellipsis", action: {})
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)

                Spacer()

                if isLoadingLibraryImage {
                    ProgressView()
                        .tint(.white)
                        .padding(.bottom, 16)
                }

                HStack {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        controlCircle(systemImage: "photo.on.rectangle")
                    }
                    .disabled(isLoadingLibraryImage)

                    Spacer()

                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 76, height: 76)
                            Circle()
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                .frame(width: 76, height: 76)
                        }
                    }
                    .disabled(!cameraController.isReady || isLoadingLibraryImage)

                    Spacer()

                    Button(action: toggleFlash) {
                        Circle()
                            .fill(isFlashEnabled ? Color.white.opacity(0.82) : Color.white.opacity(0.18))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.78) : .white)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!cameraController.isFlashAvailable || isLoadingLibraryImage)
                    .opacity(cameraController.isFlashAvailable ? 1 : 0.45)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal, 30)
                .padding(.bottom, 28)
            }
        }
        .task {
            await cameraController.start()
        }
        .onDisappear {
            cameraController.stop()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            loadSelectedPhoto(from: newItem)
        }
    }

    private func capturePhoto() {
        cameraController.capturePhoto(flashMode: isFlashEnabled ? .on : .off) { image in
            onCapture(image)
        }
    }

    private func toggleFlash() {
        guard cameraController.isFlashAvailable else { return }
        isFlashEnabled.toggle()
    }

    private func loadSelectedPhoto(from item: PhotosPickerItem) {
        isLoadingLibraryImage = true

        Task {
            defer { isLoadingLibraryImage = false }

            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                return
            }

            onCapture(image)
        }
    }

    private func circularControlButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            controlCircle(systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func controlCircle(systemImage: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.82))
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.78))
            }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }

        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

private final class CameraSessionController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var isReady = false
    @Published var errorMessage: String?
    @Published var isFlashAvailable = false

    private let sessionQueue = DispatchQueue(label: "driplog.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var hasConfiguredSession = false
    private var captureHandler: ((UIImage) -> Void)?

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await configureAndStartSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                await MainActor.run {
                    errorMessage = "Camera access is disabled. Allow camera access in Settings."
                }
                return
            }
            await configureAndStartSession()
        default:
            await MainActor.run {
                errorMessage = "Camera access is disabled. Allow camera access in Settings."
            }
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(flashMode: AVCaptureDevice.FlashMode, onCapture: @escaping (UIImage) -> Void) {
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        captureHandler = onCapture
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func configureAndStartSession() async {
        sessionQueue.async {
            if !self.hasConfiguredSession {
                self.configureSession()
            }

            guard self.hasConfiguredSession else { return }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.errorMessage = nil
                self.isReady = true
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        defer {
            session.commitConfiguration()
        }

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            DispatchQueue.main.async {
                self.errorMessage = "Could not start the camera."
                self.isReady = false
            }
            return
        }

        session.addInput(input)
        DispatchQueue.main.async {
            self.isFlashAvailable = camera.hasFlash
        }

        guard session.canAddOutput(photoOutput) else {
            DispatchQueue.main.async {
                self.errorMessage = "Could not capture photos on this device."
                self.isReady = false
            }
            return
        }

        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true
        hasConfiguredSession = true
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else { return }
        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data),
            let captureHandler
        else {
            return
        }

        DispatchQueue.main.async {
            captureHandler(image)
        }
    }
}

#Preview {
    HomeView(user: AppUser(id: UUID(), name: "Michael", email: "michael@example.com"), onLogOut: {})
}
