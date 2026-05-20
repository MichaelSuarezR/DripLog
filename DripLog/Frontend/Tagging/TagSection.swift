import SwiftUI

struct TagSection<Content: View>: View {
    let title: String
    let placeholder: String
    let section: ClosetFilterSection
    let isExpanded: Bool
    let summary: String
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(AppFont.uiRegular(size: 16))
                        .foregroundStyle(.black)

                    Spacer()

                    Text(summary.isEmpty ? placeholder : summary)
                        .font(AppFont.uiRegular(size: 16))
                        .foregroundStyle(summary.isEmpty ? AppColor.placeholderBlue : .black)
                        .lineLimit(1)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.leading, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(AppAnimation.accordionSpring, value: isExpanded)
    }
}
