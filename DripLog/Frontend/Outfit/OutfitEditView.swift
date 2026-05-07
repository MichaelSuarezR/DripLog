import SwiftUI

struct OutfitEditView: View {
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

    // MARK: - Header

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

    // MARK: - Section Builder

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

    // MARK: - Rating

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

    // MARK: - Chip Helpers

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

    // MARK: - Bindings

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

    private func editorSummary(for section: ClosetFilterSection) -> String {
        switch section {
        case .rating:
            return filters.rating.map { "\($0) stars" } ?? ""
        case .categories:
            let count = filters.categorySelectionCount
            return count == 0 ? "" : "\(count) selected"
        case .weather:    return selectionSummary(for: filters.weather)
        case .occasion:   return selectionSummary(for: filters.occasion)
        case .colors:     return selectionSummary(for: filters.colors)
        case .custom:     return selectionSummary(for: filters.custom)
        case .visibility: return visibility.title
        }
    }

    private func selectionSummary(for values: Set<String>) -> String {
        guard !values.isEmpty else { return "" }
        if values.count == 1, let first = values.first { return first }
        return "\(values.count) selected"
    }

    // MARK: - Actions

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