import PhotosUI
import SwiftUI
import UIKit

struct OnboardingCoordinator: View {
    let user: AppUser
    let onUserUpdated: (AppUser) -> Void
    let onFinish: () -> Void

    private enum Step: Equatable {
        case intro
        case photoGrid
        case tagging(slotID: String)
    }

    @State private var step: Step = .intro
    @State private var introPageIndex = 0
    @State private var profileSlot = OnboardingSlotState(kind: .profile)
    @State private var outfitSlots: [OnboardingSlotState] = (0..<5).map { OnboardingSlotState(kind: .outfit($0)) }
    @State private var isFinishing = false
    @State private var filters = ClosetFilters()
    @State private var taggingImage: UIImage?
    @State private var taggingSlotIndex: Int?
    @State private var isSavingTags = false

    @Namespace private var heroNamespace

    @State private var authService: AuthServicing?
    @State private var outfitService: OutfitServicing?

    private var canFinishOnboarding: Bool {
        profileSlot.didUpload && outfitSlots.allSatisfy(\.didUpload)
    }

    private var activeHeroSlotID: String? {
        if case .tagging(let slotID) = step { return slotID }
        return nil
    }

    var body: some View {
        ZStack {
            switch step {
            case .intro:
                OnboardingView(pageIndex: $introPageIndex) {
                    withAnimation(AppAnimation.standardSpring) {
                        step = .photoGrid
                    }
                }
                .transition(wizardTransition)

            case .photoGrid:
                OnboardingPhotoGridView(
                    profileSlot: profileSlot,
                    outfitSlots: outfitSlots,
                    heroNamespace: heroNamespace,
                    activeHeroSlotID: activeHeroSlotID,
                    canFinish: canFinishOnboarding,
                    isFinishing: isFinishing,
                    onPickProfile: { item in
                        Task { await handleProfilePick(item) }
                    },
                    onPickOutfit: { index, item in
                        Task { await handleOutfitPick(index: index, item: item) }
                    },
                    onTapUploadedOutfit: { index in
                        openTagging(for: index)
                    },
                    onFinish: finishOnboarding
                )
                .transition(wizardTransition)

            case .tagging(let slotID):
                if let image = taggingImage {
                    taggingScreen(image: image, slotID: slotID)
                        .transition(wizardTransition)
                }
            }
        }
        .animation(AppAnimation.standardSpring, value: step)
    }

    private var wizardTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private func taggingScreen(image: UIImage, slotID: String) -> some View {
        NavigationStack {
            TagEditorView(
                configuration: .onboardingTagging,
                filters: $filters,
                heroImage: image,
                heroNamespace: heroNamespace,
                heroID: slotID,
                leadingHeaderAction: TagEditorHeaderAction(title: "Back", isDisabled: isSavingTags) {
                    withAnimation(AppAnimation.standardSpring) {
                        step = .photoGrid
                    }
                },
                trailingHeaderAction: TagEditorHeaderAction(
                    title: isSavingTags ? "Saving..." : "Save",
                    isDisabled: isSavingTags
                ) {
                    saveOptionalTags(for: slotID)
                }
            )
        }
    }

    // MARK: - Photo handling

    @MainActor
    private func handleProfilePick(_ item: PhotosPickerItem) async {
        updateProfileSlot { $0.errorMessage = nil }

        guard let image = await loadImage(from: item) else {
            updateProfileSlot { $0.errorMessage = "Could not load that photo." }
            return
        }

        updateProfileSlot {
            $0.image = image
            $0.isUploading = true
        }

        do {
            _ = try await auth().updateProfilePhoto(image, for: user.id)
            updateProfileSlot {
                $0.isUploading = false
                $0.didUpload = true
            }
            onUserUpdated(user)
        } catch {
            updateProfileSlot {
                $0.isUploading = false
                $0.errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not upload profile photo."
                $0.didUpload = false
            }
        }
    }

    @MainActor
    private func handleOutfitPick(index: Int, item: PhotosPickerItem) async {
        guard outfitSlots.indices.contains(index) else { return }
        updateOutfitSlot(at: index) { $0.errorMessage = nil }

        guard let image = await loadImage(from: item) else {
            updateOutfitSlot(at: index) { $0.errorMessage = "Could not load that photo." }
            return
        }

        updateOutfitSlot(at: index) {
            $0.image = image
            $0.isUploading = true
        }

        let emptyMetadata = OutfitMetadata(
            customTags: [],
            categories: [],
            weather: [],
            occasion: [],
            colors: []
        )

        do {
            let photo = try await outfits().uploadOutfit(image, metadata: emptyMetadata, for: user.id)
            updateOutfitSlot(at: index) {
                $0.isUploading = false
                $0.didUpload = true
                $0.uploadedOutfitID = photo.id
            }
            runBackgroundAutoTag(image: image, outfitID: photo.id)
        } catch {
            updateOutfitSlot(at: index) {
                $0.isUploading = false
                $0.errorMessage = outfitUploadMessage(for: error)
                $0.didUpload = false
            }
        }
    }

    private func updateProfileSlot(_ update: (inout OnboardingSlotState) -> Void) {
        var slot = profileSlot
        update(&slot)
        profileSlot = slot
    }

    private func updateOutfitSlot(at index: Int, _ update: (inout OnboardingSlotState) -> Void) {
        guard outfitSlots.indices.contains(index) else { return }
        var slot = outfitSlots[index]
        update(&slot)
        outfitSlots[index] = slot
    }

    private func runBackgroundAutoTag(image: UIImage, outfitID: UUID) {
        Task {
            guard let service = try? SupabaseAutoTagService(),
                  let metadata = try? await service.autoTag(image: image) else { return }
            try? await outfits().updateOutfitMetadata(metadata, for: outfitID)
        }
    }

    private func openTagging(for index: Int) {
        guard outfitSlots.indices.contains(index), let image = outfitSlots[index].image else { return }
        taggingSlotIndex = index
        taggingImage = image
        filters = ClosetFilters()
        withAnimation(AppAnimation.standardSpring) {
            step = .tagging(slotID: outfitSlots[index].id)
        }
    }

    private func saveOptionalTags(for slotID: String) {
        guard let taggingSlotIndex,
              outfitSlots.indices.contains(taggingSlotIndex),
              let outfitID = outfitSlots[taggingSlotIndex].uploadedOutfitID else {
            withAnimation(AppAnimation.standardSpring) { step = .photoGrid }
            return
        }

        Task {
            isSavingTags = true
            defer { isSavingTags = false }
            do {
                try await outfits().updateOutfitMetadata(filters.metadata, for: outfitID)
            } catch {
                // Tagging is optional; still allow returning to grid.
            }
            withAnimation(AppAnimation.standardSpring) {
                step = .photoGrid
            }
        }
    }

    private func finishOnboarding() {
        guard canFinishOnboarding, !isFinishing else { return }
        isFinishing = true
        onFinish()
    }

    // MARK: - Utilities

    private func loadImage(from item: PhotosPickerItem) async -> UIImage? {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return nil }
        return image
    }

    private func outfitUploadMessage(for error: Error) -> String {
        let fallback = String(describing: error)
        if fallback.contains("NSURLErrorDomain Code=-1001")
            || fallback.localizedCaseInsensitiveContains("timed out") {
            return "Could not save outfit photo: The upload timed out. Try again on a stronger connection."
        }
        let description = (error as? LocalizedError)?.errorDescription
        let details = [description, fallback]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0 != "The operation couldn't be completed." }
            ?? "Unknown error"
        return "Could not save outfit photo: \(details)"
    }

    private func auth() throws -> AuthServicing {
        if let authService { return authService }
        let created = try SupabaseAuthService()
        authService = created
        return created
    }

    private func outfits() throws -> OutfitServicing {
        if let outfitService { return outfitService }
        let created = try SupabaseOutfitService()
        outfitService = created
        return created
    }
}
