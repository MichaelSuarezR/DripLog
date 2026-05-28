import SwiftUI
import UIKit

// MARK: - Configuration

enum TagEditorMode {
    case filter
    case outfitUpload
    case editTags
    case onboardingTagging
}

struct TagEditorConfiguration {
    let mode: TagEditorMode
    let title: String
    let showsRating: Bool
    let showsVisibility: Bool
    let showsPromptRow: Bool
    let showsAISection: Bool
    let showsCustomSuggestions: Bool
    let showsNotes: Bool
    let showsAdditionalImages: Bool
    let showsFooterActions: Bool
    let autoTagOnAppear: Bool

    static let filter = TagEditorConfiguration(
        mode: .filter,
        title: "Filter",
        showsRating: true,
        showsVisibility: true,
        showsPromptRow: false,
        showsAISection: false,
        showsCustomSuggestions: true,
        showsNotes: false,
        showsAdditionalImages: false,
        showsFooterActions: false,
        autoTagOnAppear: false
    )

    static let outfitUpload = TagEditorConfiguration(
        mode: .outfitUpload,
        title: "Outfit Upload",
        showsRating: false,
        showsVisibility: false,
        showsPromptRow: true,
        showsAISection: true,
        showsCustomSuggestions: true,
        showsNotes: false,
        showsAdditionalImages: false,
        showsFooterActions: false,
        autoTagOnAppear: true
    )

    static let editTags = TagEditorConfiguration(
        mode: .editTags,
        title: "Edit Tags",
        showsRating: false,
        showsVisibility: false,
        showsPromptRow: true,
        showsAISection: true,
        showsCustomSuggestions: true,
        showsNotes: true,
        showsAdditionalImages: true,
        showsFooterActions: true,
        autoTagOnAppear: true
    )

    static let onboardingTagging = TagEditorConfiguration(
        mode: .onboardingTagging,
        title: "Outfit Upload",
        showsRating: false,
        showsVisibility: false,
        showsPromptRow: true,
        showsAISection: true,
        showsCustomSuggestions: false,
        showsNotes: false,
        showsAdditionalImages: false,
        showsFooterActions: false,
        autoTagOnAppear: true
    )
}

// MARK: - TagEditorView

struct TagEditorView: View {
    let configuration: TagEditorConfiguration
    @Binding var filters: ClosetFilters
    var promptText: Binding<String>? = nil
    let heroImage: UIImage?
    var heroNamespace: Namespace.ID?
    var heroID: String?
    var visibility: Binding<OutfitVisibility>?
    var leadingHeaderAction: TagEditorHeaderAction?
    var trailingHeaderAction: TagEditorHeaderAction?
    var onAutoTagComplete: ((OutfitMetadata) -> Void)?
    var footer: AnyView?

    @State private var expandedSections: Set<ClosetFilterSection> = []
    @State private var internalTagInput = ""
    @State private var isAutoTagging = false
    @State private var autoTagError: String?
    @State private var notes = ""
    @State private var aiSuggestedChips: [String] = []

    private let uploadSuggestedTags = [
        "Black Top", "Dark Blue Jeans", "Red Scarf", "Flared Leggings",
        "White Sneakers", "Brown Leather Belt", "Black Hoodie",
        "Blue Denim Jacket", "Gray Sweatpants", "Gold Jewelry"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: configuration.mode == .filter ? 24 : 18) {
                headerBar

                if let autoTagError {
                    Text(autoTagError)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if configuration.showsPromptRow, let heroImage {
                    promptRow(image: heroImage)
                }

                if configuration.showsAISection {
                    aiSuggestedSection
                }

                tagChips

                metadataSections

                if configuration.showsCustomSuggestions {
                    customSuggestionsList
                }

                if configuration.showsAdditionalImages {
                    additionalImagesSection
                }

                if configuration.showsNotes {
                    notesSection
                }

                if let footer {
                    footer
                }
            }
            .padding(.horizontal, configuration.mode == .filter ? 16 : 20)
            .padding(.top, configuration.mode == .filter ? 6 : 16)
            .padding(.bottom, 32)
        }
        .background(Color.white)
        .onAppear {
            if configuration.mode == .filter {
                expandedSections = [.rating, .categories, .weather]
            }
        }
        .task(id: configuration.autoTagOnAppear) {
            guard configuration.autoTagOnAppear, let heroImage else { return }
            await performAutoTag(image: heroImage)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerBar: some View {
        switch configuration.mode {
        case .filter, .editTags:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.10))
                    .frame(height: 56)

                Text(configuration.title)
                    .font(AppFont.uiBold(size: 22))
                    .foregroundStyle(.black)

                HStack {
                    if let leadingHeaderAction {
                        headerButton(leadingHeaderAction)
                    }
                    Spacer()
                    if let trailingHeaderAction {
                        headerButton(trailingHeaderAction)
                    }
                }
                .padding(.horizontal, 10)
            }
        case .outfitUpload, .onboardingTagging:
            VStack(spacing: 8) {
                HStack {
                    if let leadingHeaderAction {
                        headerButton(leadingHeaderAction)
                    }
                    Spacer()
                    Text(configuration.title)
                        .font(AppFont.uiRegular(size: 16))
                        .foregroundStyle(.black)
                    Spacer()
                    if let trailingHeaderAction {
                        headerButton(trailingHeaderAction)
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func headerButton(_ action: TagEditorHeaderAction) -> some View {
        Button(action: action.handler) {
            Group {
                if let systemImage = action.systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(.black)
                } else {
                    Text(action.title)
                        .font(AppFont.uiRegular(size: 16))
                        .foregroundStyle(.black)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action.isDisabled)
        .opacity(action.isDisabled ? 0.4 : 1)
    }

    // MARK: - Prompt row

    private func promptRow(image: UIImage) -> some View {
        HStack(alignment: .top, spacing: 16) {
            TextField("What are you wearing?", text: promptBinding)
                .font(AppFont.uiRegular(size: 16))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { addCustomTag(promptBinding.wrappedValue) }

            heroThumbnail(image: image)
        }
    }

    @ViewBuilder
    private func heroThumbnail(image: UIImage) -> some View {
        let thumbnail = Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 82, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipped()

        if let heroNamespace, let heroID {
            thumbnail
                .matchedGeometryEffect(id: heroID, in: heroNamespace, properties: .frame, isSource: false)
        } else {
            thumbnail
        }
    }

    // MARK: - AI section

    private var aiSuggestedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI Suggested Tags")
                .font(AppFont.uiRegular(size: 16))
                .foregroundStyle(.black)

            HStack(spacing: 10) {
                AIGlowButton(title: "AI", isLoading: $isAutoTagging) {
                    guard let heroImage else { return }
                    await performAutoTag(image: heroImage)
                }

                ForEach(aiSuggestedChips.prefix(3), id: \.self) { chip in
                    aiChipButton(chip)
                }
            }
        }
        .padding(.top, 4)
        .tutorialAnchor(step: .aiTags)
    }

    private func aiChipButton(_ label: String) -> some View {
        Button {
            addCustomTag(label)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(AppColor.aiChipTint)
                Text(label)
                    .font(AppFont.uiRegular(size: 12))
                    .foregroundStyle(AppColor.aiChipTint)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColor.loadingBlue, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tag chips

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
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Metadata sections

    private var metadataSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            if configuration.showsRating {
                section(.rating, title: "Rating", placeholder: "Give a rating") {
                    ratingRow
                }
            }

            section(.categories, title: categoryTitle, placeholder: categoryPlaceholder) {
                categoriesContent
            }

            section(.weather, title: "Weather", placeholder: "Choose the weather") {
                TagChipGrid(
                    items: ClosetFilters.weatherOptions,
                    selected: $filters.weather,
                    showsClearButton: configuration.mode == .filter,
                    onClear: { filters.weather.removeAll() }
                )
            }

            section(.occasion, title: "Occasion", placeholder: "Choose the occassion") {
                TagChipGrid(
                    items: ClosetFilters.occasionOptions,
                    selected: $filters.occasion,
                    showsClearButton: configuration.mode == .filter,
                    onClear: { filters.occasion.removeAll() }
                )
            }

            section(.colors, title: "Colors", placeholder: "Choose the colors") {
                TagChipGrid(
                    items: ClosetFilters.colorOptions,
                    selected: $filters.colors,
                    showsClearButton: configuration.mode == .filter,
                    onClear: { filters.colors.removeAll() }
                )
            }

            section(.custom, title: "Custom", placeholder: "Choose your custom tags") {
                TagChipGrid(
                    items: filters.customSuggestions,
                    selected: $filters.custom,
                    showsClearButton: configuration.mode == .filter,
                    onClear: { filters.custom.removeAll() }
                )
            }

            if configuration.showsVisibility, let visibility {
                section(.visibility, title: "Visibility", placeholder: "Choose your visibility") {
                    TagChipGrid(
                        items: OutfitVisibility.allCases.map(\.title),
                        selected: visibilityBinding(visibility)
                    )
                }
            }
        }
        .padding(.top, configuration.showsPromptRow ? 12 : 0)
        .tutorialAnchor(step: .dropdowns)
    }

    private var categoryTitle: String {
        configuration.mode == .filter ? "Categories" : "Category"
    }

    private var categoryPlaceholder: String {
        configuration.mode == .filter ? "Choose a category" : "Choose a category"
    }

    @ViewBuilder
    private var categoriesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ClosetCategoryGroup.allCases) { group in
                VStack(alignment: .leading, spacing: 10) {
                    TagCategoryGroupChip(title: group.title)
                    TagChipGrid(items: group.items, selected: binding(for: group))
                }
            }

            if configuration.mode == .filter {
                Button("Clear all") { filters.clearCategories() }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.35))
                    .padding(.horizontal, 14)
                    .frame(height: 24)
                    .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .buttonStyle(.plain)
            }
        }
    }

    private func section<Content: View>(
        _ section: ClosetFilterSection,
        title: String,
        placeholder: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        TagSection(
            title: title,
            placeholder: placeholder,
            section: section,
            isExpanded: expandedSections.contains(section),
            summary: sectionSummary(for: section),
            onToggle: { toggle(section) },
            content: { content() }
        )
    }

    private var ratingRow: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    filters.rating = filters.rating == value ? nil : value
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(
                            value <= (filters.rating ?? 0)
                                ? Color(red: 1.0, green: 0.84, blue: 0.24)
                                : Color.black.opacity(0.18)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Custom suggestions

    @ViewBuilder
    private var customSuggestionsList: some View {
        if configuration.mode == .outfitUpload {
            Divider()
                .padding(.top, 18)
                .padding(.bottom, 16)

            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(filteredSuggestions, id: \.self) { tag in
                    Button {
                        addCustomTag(tag)
                    } label: {
                        Text(tag)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var promptBinding: Binding<String> {
        promptText ?? $internalTagInput
    }

    private var filteredSuggestions: [String] {
        let normalizedInput = promptBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedTags = Array(filters.custom)

        if normalizedInput.isEmpty {
            return uploadSuggestedTags.filter { !selectedTags.contains($0) }
        }

        return uploadSuggestedTags.filter {
            !selectedTags.contains($0) && $0.localizedCaseInsensitiveContains(normalizedInput)
        }
    }

    // MARK: - Additional sections

    private var additionalImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(Color.black.opacity(0.4))

            Text("Additional Images")
                .font(.title3.weight(.semibold))

            Button {} label: {
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [2.5]))
                    .foregroundStyle(Color.black.opacity(0.5))
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
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(Color.black.opacity(0.4))

            Text("Notes")
                .font(.title3.weight(.semibold))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColor.placeholderBlue.opacity(0.35))
                    .frame(height: 138)

                TextEditor(text: $notes)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: 138)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Write here")
                        .font(AppFont.uiLight(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                }
            }
        }
    }

    // MARK: - Helpers

    private func binding(for group: ClosetCategoryGroup) -> Binding<Set<String>> {
        switch group {
        case .tops:        return $filters.topCategories
        case .bottoms:     return $filters.bottomCategories
        case .outerwear:   return $filters.outerwearCategories
        case .shoes:       return $filters.shoesCategories
        case .accessories: return $filters.accessoriesCategories
        }
    }

    private func visibilityBinding(_ visibility: Binding<OutfitVisibility>) -> Binding<Set<String>> {
        Binding(
            get: { [visibility.wrappedValue.title] },
            set: { values in
                if let value = values.first, let selected = OutfitVisibility(title: value) {
                    visibility.wrappedValue = selected
                }
            }
        )
    }

    private func toggle(_ section: ClosetFilterSection) {
        withAnimation(AppAnimation.accordionSpring) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    private func sectionSummary(for section: ClosetFilterSection) -> String {
        switch section {
        case .rating:
            return filters.rating.map { "\($0) stars" } ?? ""
        case .categories:
            let count = filters.categorySelectionCount
            return count == 0 ? "" : "\(count) selected"
        case .weather:  return summaryText(for: filters.weather)
        case .occasion: return summaryText(for: filters.occasion)
        case .colors:   return summaryText(for: filters.colors)
        case .custom:   return summaryText(for: filters.custom)
        case .visibility:
            return visibility?.wrappedValue.title ?? ""
        }
    }

    private func summaryText(for set: Set<String>) -> String {
        guard !set.isEmpty else { return "" }
        if set.count == 1, let value = set.first { return value }
        return "\(set.count) selected"
    }

    func flushPendingCustomTag() {
        addCustomTag(promptBinding.wrappedValue)
    }

    private func addCustomTag(_ rawTag: String) {
        let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        guard !filters.custom.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else {
            promptBinding.wrappedValue = ""
            return
        }
        filters.custom.insert(tag)
        promptBinding.wrappedValue = ""
    }

    private func performAutoTag(image: UIImage) async {
        isAutoTagging = true
        autoTagError = nil
        defer { isAutoTagging = false }

        do {
            let service = try SupabaseAutoTagService()
            let result = try await service.autoTag(image: image)
            applyAutoTagResult(result)
            onAutoTagComplete?(result)
        } catch let error as AutoTagError {
            autoTagError = error.errorDescription
        } catch {
            autoTagError = AutoTagError.backendFailed.errorDescription
        }
    }

    private func applyAutoTagResult(_ result: OutfitMetadata) {
        let autoFilters = ClosetFilters(metadata: result)
        filters.topCategories.formUnion(autoFilters.topCategories)
        filters.bottomCategories.formUnion(autoFilters.bottomCategories)
        filters.outerwearCategories.formUnion(autoFilters.outerwearCategories)
        filters.shoesCategories.formUnion(autoFilters.shoesCategories)
        filters.accessoriesCategories.formUnion(autoFilters.accessoriesCategories)
        filters.weather.formUnion(autoFilters.weather)
        filters.occasion.formUnion(autoFilters.occasion)
        filters.colors.formUnion(autoFilters.colors)

        aiSuggestedChips = Array(
            autoFilters.selectedCategories.prefix(3)
                + autoFilters.weather.prefix(1)
                + autoFilters.colors.prefix(1)
        ).map { $0.capitalized }

        if autoFilters.categorySelectionCount > 0 { expandedSections.insert(.categories) }
        if !autoFilters.weather.isEmpty  { expandedSections.insert(.weather) }
        if !autoFilters.occasion.isEmpty { expandedSections.insert(.occasion) }
        if !autoFilters.colors.isEmpty   { expandedSections.insert(.colors) }
    }
}

struct TagEditorHeaderAction {
    let title: String
    var systemImage: String?
    var isDisabled: Bool
    let handler: () -> Void

    init(title: String, systemImage: String? = nil, isDisabled: Bool = false, handler: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.handler = handler
    }
}
