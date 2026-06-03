import SwiftUI
import UIKit

struct OutfitEditView: View {
    let photo: OutfitPhoto
    let onClose: (OutfitMetadata) async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var filters: ClosetFilters
    @State private var visibility: OutfitVisibility
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var loadedImage: UIImage?

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
                colors: photo.colors,
                visibility: photo.visibility
            )
        ))
        _visibility = State(initialValue: photo.visibility)
    }

    var body: some View {
        NavigationStack {
            TagEditorView(
                configuration: .editTags,
                filters: $filters,
                heroImage: loadedImage,
                visibility: $visibility,
                leadingHeaderAction: TagEditorHeaderAction(
                    title: "",
                    systemImage: "xmark.circle",
                    isDisabled: isSaving || isDeleting,
                    handler: closeWithoutSaving
                ),
                footer: AnyView(deleteFooter)
            )
            .task { await loadHeroImage() }
            .modalEntryTransition()
        }
    }

    private var deleteFooter: some View {
        VStack {
            Button(role: .destructive) {
                deleteOutfit()
            } label: {
                Text(isDeleting ? "Deleting..." : "Delete outfit")
                    .font(AppFont.uiBold(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 174, height: 34)
                    .background(AppColor.accentOrange, in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .disabled(isDeleting || isSaving)
        }
        .padding(.top, 28)
    }

    private func loadHeroImage() async {
        guard let (data, _) = try? await URLSession.shared.data(from: photo.imageURL),
              let image = UIImage(data: data) else { return }
        await MainActor.run { loadedImage = image }
    }

    private func closeWithoutSaving() {
        guard !isSaving, !isDeleting else { return }
        dismiss()
    }

    private func deleteOutfit() {
        guard !isDeleting, !isSaving else { return }
        isDeleting = true
        dismiss()
        Task {
            await onDelete()
        }
    }
}
