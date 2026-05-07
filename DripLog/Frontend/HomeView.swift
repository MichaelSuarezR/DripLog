//
//  HomeView.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

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

    // MARK: - Tab Routing

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

    // MARK: - Outfit Loading

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
                    imageURL: existing.imageURL,
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

    // MARK: - Suggestions

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
    HomeView(user: AppUser(id: UUID(), name: "Michael", email: "michael@example.com"), onLogOut: {})
}