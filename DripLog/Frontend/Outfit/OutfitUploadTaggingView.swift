import SwiftUI
import UIKit

struct OutfitUploadTaggingView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onSave: (OutfitMetadata) async throws -> Void

    @State private var filters = ClosetFilters()
    @State private var promptText = ""
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            TagEditorView(
                configuration: .outfitUpload,
                filters: $filters,
                promptText: $promptText,
                heroImage: image,
                leadingHeaderAction: TagEditorHeaderAction(title: "Cancel", isDisabled: isSaving, handler: onCancel),
                trailingHeaderAction: TagEditorHeaderAction(
                    title: isSaving ? "Saving..." : "Save",
                    isDisabled: isSaving,
                    handler: saveOutfit
                )
            )
            .overlay(alignment: .top) {
                if let saveError {
                    Text(saveError)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
            }
            .modalEntryTransition()
        }
    }

    private func saveOutfit() {
        guard !isSaving else { return }

        let trimmedInput = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
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
                saveError = Self.saveErrorMessage(for: error)
            }
        }
    }

    private static func saveErrorMessage(for error: Error) -> String {
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
}
