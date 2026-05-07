
import SwiftUI
import UIKit

struct OutfitUploadTaggingView: View {
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
                            Button {
                                addTag(tag)
                            } label: {
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

    // MARK: - Header

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

    // MARK: - Prompt Row

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

    // MARK: - Tag Chips

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

    // MARK: - Metadata Sections

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

    // MARK: - Section Builder

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

    // MARK: - Chip Helpers

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

    // MARK: - Bindings

    private func binding(for group: ClosetCategoryGroup) -> Binding<Set<String>> {
        switch group {
        case .tops:        return $filters.topCategories
        case .bottoms:     return $filters.bottomCategories
        case .outerwear:   return $filters.outerwearCategories
        case .shoes:       return $filters.shoesCategories
        case .accessories: return $filters.accessoriesCategories
        }
    }

    // MARK: - Helpers

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
        case .weather:  return summaryText(for: filters.weather)
        case .occasion: return summaryText(for: filters.occasion)
        case .colors:   return summaryText(for: filters.colors)
        case .custom:   return summaryText(for: filters.custom)
        case .rating, .visibility: return ""
        }
    }

    private func summaryText(for set: Set<String>) -> String {
        guard !set.isEmpty else { return "" }
        if set.count == 1, let value = set.first { return value }
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

    // MARK: - Actions

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