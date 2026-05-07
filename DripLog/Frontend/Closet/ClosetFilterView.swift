

import SwiftUI

struct ClosetFilterView: View {
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
                            clearButton { filters.weather.removeAll() }
                        }
                    }

                    filterSection(
                        title: "Occasion",
                        placeholder: "Choose the occassion",
                        section: .occasion
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            chipGrid(items: ClosetFilters.occasionOptions, selected: $filters.occasion)
                            clearButton { filters.occasion.removeAll() }
                        }
                    }

                    filterSection(
                        title: "Colors",
                        placeholder: "Choose the colors",
                        section: .colors
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            chipGrid(items: ClosetFilters.colorOptions, selected: $filters.colors)
                            clearButton { filters.colors.removeAll() }
                        }
                    }

                    filterSection(
                        title: "Custom",
                        placeholder: "Choose your custom tags",
                        section: .custom
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            chipGrid(items: filters.customSuggestions, selected: $filters.custom)
                            clearButton { filters.custom.removeAll() }
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

    // MARK: - Header

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

    // MARK: - Rating

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

    // MARK: - Section Builder

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

    private func clearButton(action: @escaping () -> Void) -> some View {
        Button("Clear all", action: action)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.black.opacity(0.35))
            .padding(.horizontal, 14)
            .frame(height: 24)
            .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .buttonStyle(.plain)
    }

    // MARK: - Helpers

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
            return filters.rating.map { "\($0) stars" } ?? ""
        case .categories:
            let count = filters.categorySelectionCount
            return count == 0 ? "" : "\(count) selected"
        case .weather:    return summaryText(for: filters.weather)
        case .occasion:   return summaryText(for: filters.occasion)
        case .colors:     return summaryText(for: filters.colors)
        case .custom:     return summaryText(for: filters.custom)
        case .visibility: return ""
        }
    }

    private func summaryText(for set: Set<String>) -> String {
        guard !set.isEmpty else { return "" }
        if set.count == 1, let value = set.first { return value }
        return "\(set.count) selected"
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
}