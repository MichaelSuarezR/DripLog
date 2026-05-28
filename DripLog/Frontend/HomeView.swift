// HomeView.swift — FULL FILE

import SwiftUI
import UIKit

// MARK: - AppTab

enum AppTab {
    case closet
    case add
    case feed
}

// MARK: - PendingOutfitDraft

struct PendingOutfitDraft: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - HomeView

struct HomeView: View {
    let user: AppUser
    let onUserUpdated: (AppUser) -> Void
    let onLogOut: () -> Void

    @State private var selectedTab: AppTab = .feed
    @State private var pendingOutfitDraft: PendingOutfitDraft?
    @State private var editingOutfit: OutfitPhoto?
    @State private var outfitPhotos: [OutfitPhoto] = []
    @State private var outfitErrorMessage: String?
    @State private var didLoadOutfits = false
    @State private var isLoadingOutfits = false
    @State private var outfitService: OutfitServicing?
    @State private var suggestionService: SuggestionServicing?
    @State private var isSuggestionsPresented = false
    @State private var isProfilePresented = false
    @State private var isLoadingSuggestions = false
    @State private var suggestions: OutfitSuggestions?
    @State private var suggestionsLocalDate: String?
    @State private var suggestionErrorMessage: String?

    // MARK: Tutorial state
    @StateObject private var tutorialManager: TutorialManager
    @State private var tutorialPhotoImage: UIImage?
    @State private var isTutorialTagEditorOpen = false
    @State private var tutorialDidAttemptOpen = false

    init(user: AppUser, onUserUpdated: @escaping (AppUser) -> Void, onLogOut: @escaping () -> Void) {
    self.user = user
    self.onUserUpdated = onUserUpdated
    self.onLogOut = onLogOut
    _tutorialManager = StateObject(wrappedValue: TutorialManager(userID: user.id.uuidString))
}

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTabView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
        }
        .environmentObject(tutorialManager)
        .onPreferenceChange(TutorialAnchorKey.self) { anchors in
            for anchor in anchors {
                tutorialManager.registerFrame(anchor.frame, for: anchor.step)
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            guard newTab == .closet else { return }
            Task { await loadOutfitsIfNeeded() }
        }
        .onChange(of: outfitPhotos.count) { _, count in
            guard
                !tutorialDidAttemptOpen,
                tutorialManager.shouldShow,
                count > 0
            else { return }

            tutorialDidAttemptOpen = true

            Task {
                await openTutorialTagEditor(photos: outfitPhotos)
            }
        }
        .onChange(of: tutorialManager.currentStep) { _, step in
            handleTutorialStepChange(step)
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
            .modalEntryTransition()
        }
        .fullScreenCover(isPresented: $isTutorialTagEditorOpen) {
            if let image = tutorialPhotoImage {
                OutfitUploadTaggingView(
                    image: image,
                    isTutorial: true,
                    onCancel: {
                        // User dismissed tutorial tag editor — skip to closet steps
                        isTutorialTagEditorOpen = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = .closet
                            tutorialManager.currentStep = .closetGrid
                            tutorialManager.isActive = true
                        }
                    },
                    onSave: { _ in
                        // Don't re-upload — photo already uploaded during onboarding
                        // Just advance tutorial to closet
                        isTutorialTagEditorOpen = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = .closet
                            tutorialManager.currentStep = .closetGrid
                            tutorialManager.isActive = true
                        }
                    }
                )
                .environmentObject(tutorialManager)
                .modalEntryTransition()
            }
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
            .modalEntryTransition()
        }
        .fullScreenCover(isPresented: $isSuggestionsPresented) {
            SuggestionsView(
                suggestions: suggestions,
                isLoading: isLoadingSuggestions,
                errorMessage: suggestionErrorMessage,
                onClose: { isSuggestionsPresented = false },
                onRetry: prepareSuggestions
            )
        }
        .fullScreenCover(isPresented: $isProfilePresented) {
            UserProfileView(
                user: user,
                onUserUpdated: onUserUpdated,
                onClose: { isProfilePresented = false },
                onLogOut: {
                    isProfilePresented = false
                    onLogOut()
                }
            )
        }
    }

    // MARK: - Tab Routing

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .closet:
            ProfileTab(
                user: user,
                outfitPhotos: outfitPhotos,
                isLoadingOutfits: isLoadingOutfits,
                errorMessage: outfitErrorMessage,
                onLogOut: onLogOut,
                onEditOutfit: { editingOutfit = $0 },
                onAskForSuggestions: prepareSuggestions,
                onProfileTapped: { isProfilePresented = true },
                onLoadOutfits: { await loadOutfitsIfNeeded() },
                onRefreshOutfits: { await loadOutfits(force: true) }
            )
        case .add:
            CreateTab(
                isUploading: false,
                errorMessage: outfitErrorMessage,
                onCapture: prepareOutfit
            )
        case .feed:
            HomeTab(
                user: user,
                onProfileTapped: { isProfilePresented = true }
            )
        }
    }

    // MARK: - Tutorial Helpers

    private func openTutorialTagEditor(photos: [OutfitPhoto]) async {
        guard let randomPhoto = photos.randomElement() else { return }
        let url = randomPhoto.imageURL

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }
            tutorialPhotoImage = image
            tutorialManager.start()
            isTutorialTagEditorOpen = true
        } catch {
            // If image fails to load, skip tag editor steps and start from closet
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = .closet
                tutorialManager.currentStep = .closetGrid
                tutorialManager.isActive = true
            }
        }
    }

    private func handleTutorialStepChange(_ step: TutorialStep) {
        switch step {
        case .closetGrid, .generateOutfit:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = .closet
            }
        case .feed:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = .feed
            }
        default:
            break
        }
    }

    // MARK: - Outfit Loading

    private func loadOutfitsIfNeeded() async {
        await loadOutfits(force: false)
    }

    private func loadOutfits(force: Bool) async {
        guard (force || !didLoadOutfits), !isLoadingOutfits else { return }
        isLoadingOutfits = true
        outfitErrorMessage = nil
        defer { isLoadingOutfits = false }

        do {
            outfitPhotos = try await service().fetchOutfits(for: user.id)
            didLoadOutfits = true
            Task {
                await ImageCache.shared.prefetch(urls: outfitPhotos.map(\.imageURL))
            }
        } catch is CancellationError {
            return
        } catch {
            outfitErrorMessage = Self.outfitLoadMessage(for: error)
        }
    }

    private static func outfitLoadMessage(for error: Error) -> String {
        let fallback = String(describing: error)
        let description = (error as? LocalizedError)?.errorDescription
        let details = [description, fallback]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0 != "The operation couldn't be completed." }
            ?? "Unknown error"
        return "Could not load saved outfits: \(details)"
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
                    imageURL: existing.imageURL,
                    tags: metadata.allTags,
                    customTags: metadata.customTags,
                    categories: metadata.categories,
                    weather: metadata.weather,
                    occasion: metadata.occasion,
                    colors: metadata.colors,
                    visibility: metadata.visibility,
                    createdAt: existing.createdAt
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

    // MARK: - Suggestions

    private func prepareSuggestions() {
        let today = Self.localDateString()

        if suggestions != nil && suggestionsLocalDate == today {
            suggestionErrorMessage = nil
            isLoadingSuggestions = false
            isSuggestionsPresented = true
            return
        }

        isSuggestionsPresented = true
        isLoadingSuggestions = true
        suggestionErrorMessage = nil
        suggestions = nil

        Task {
            do {
                let result = try await suggestionProvider().makeSuggestions(for: user, outfitPhotos: outfitPhotos)
                let imageURLs = [
                    result.leftOutfit.thumbnailURL,
                    result.centerInspiration.imageURL,
                    result.rightOutfit.thumbnailURL
                ]
                await ImageCache.shared.prefetch(urls: imageURLs)
                suggestions = result
                suggestionsLocalDate = today
            } catch {
                suggestionErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not build suggestions right now."
            }
            isLoadingSuggestions = false
        }
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

    // MARK: - Service Accessors

    private func service() throws -> OutfitServicing {
        if let outfitService { return outfitService }
        let createdService = try SupabaseOutfitService()
        outfitService = createdService
        return createdService
    }

    private func suggestionProvider() throws -> SuggestionServicing {
        if let suggestionService { return suggestionService }
        let createdService = try SupabaseSuggestionService()
        suggestionService = createdService
        return createdService
    }
}

// MARK: - Preview

#Preview {
    HomeView(
        user: AppUser(id: UUID(), name: "Michael", email: "michael@example.com"),
        onUserUpdated: { _ in },
        onLogOut: {}
    )
}
