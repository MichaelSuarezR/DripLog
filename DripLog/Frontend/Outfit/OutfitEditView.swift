import SwiftUI
import UIKit

struct OutfitEditView: View {
    let photo: OutfitPhoto
    let onClose: (OutfitMetadata) async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var filters: ClosetFilters
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
    }

    var body: some View {
        NavigationStack {
            TagEditorView(
                configuration: .editTags,
                filters: $filters,
                heroImage: loadedImage,
                leadingHeaderAction: TagEditorHeaderAction(
                    title: "",
                    systemImage: "xmark.circle",
                    isDisabled: isSaving || isDeleting,
                    handler: saveAndDismiss
                ),
                footer: AnyView(deleteFooter)
            )
            .task { await loadHeroImage() }
            .modalEntryTransition()
        }
    }

    private var deleteFooter: some View {
        VStack(spacing: 16) {
            Divider().overlay(Color.black.opacity(0.4))

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
            .disabled(isDeleting || isSaving)
        }
        .padding(.top, 8)
    }

    private func loadHeroImage() async {
        guard let (data, _) = try? await URLSession.shared.data(from: photo.imageURL),
              let image = UIImage(data: data) else { return }
        await MainActor.run { loadedImage = image }
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
