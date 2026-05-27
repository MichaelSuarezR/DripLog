import SwiftUI

struct OnboardingPreferencesView: View {
    @Binding var selectedGender: String
    @Binding var selectedStyle: String
    let onContinue: () -> Void

    private let genders = ["men", "women", "unisex"]
    private let styles = ["streetwear", "casual", "formal", "preppy", "vintage", "athletic", "minimalist", "bold"]

    var canContinue: Bool {
        !selectedGender.isEmpty && !selectedStyle.isEmpty
    }

    var body: some View {
        ZStack {
            AppColor.loadingBlue.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 70)

                Text("your style,\nyour rules.")
                    .font(AppFont.logo(size: 44))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 40)

                // Gender
                VStack(alignment: .leading, spacing: 12) {
                    Text("i shop for")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 32)

                    HStack(spacing: 10) {
                        ForEach(genders, id: \.self) { gender in
                            PrefChip(title: gender, isSelected: selectedGender == gender) {
                                selectedGender = gender
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer().frame(height: 36)

                // Style
                VStack(alignment: .leading, spacing: 12) {
                    Text("my style is")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 32)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(styles, id: \.self) { style in
                            PrefChip(title: style, isSelected: selectedStyle == style) {
                                selectedStyle = style
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                HStack {
                    Spacer()
                    Button(action: onContinue) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 64, height: 64)
                            .background(
                                canContinue ? Color.white : Color.white.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue)
                    .padding(.trailing, 32)
                    .padding(.bottom, 60)
                }
            }
        }
    }
}

// MARK: - PrefChip

private struct PrefChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected ? Color.white : Color.white.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.standardSpring, value: isSelected)
    }
}
