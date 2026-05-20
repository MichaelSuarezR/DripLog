import SwiftUI

struct TagChipGrid: View {
    let items: [String]
    @Binding var selected: Set<String>
    var showsClearButton: Bool = false
    var onClear: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 64, maximum: 132), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(items, id: \.self) { item in
                    let isSelected = selected.contains(item)

                    Button {
                        if isSelected {
                            selected.remove(item)
                        } else {
                            selected.insert(item)
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
                            .background(
                                Color.black.opacity(isSelected ? 0.22 : 0.12),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if showsClearButton, let onClear {
                Button("Clear all", action: onClear)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.35))
                    .padding(.horizontal, 14)
                    .frame(height: 24)
                    .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .buttonStyle(.plain)
            }
        }
    }
}

struct TagCategoryGroupChip: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
