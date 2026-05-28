import SwiftUI

// MARK: - Data

private let genderOptions = ["Masculine", "Feminine", "Prefer not to say"]

private let styleOptions = [
    "Y2K", "Streetwear", "Activewear", "Minimalist",
    "Gorpcore & Outdoors", "Vintage 90s", "Alternative",
    "Goth", "Retro", "Coquette"
]

// MARK: - Main View

struct OnboardingPreferencesView: View {
    @Binding var selectedGender: String
    @Binding var selectedStyle: String
    let onContinue: () -> Void

    @State private var genderExpanded = false
    @State private var styleExpanded = false

    var canContinue: Bool {
        !selectedGender.isEmpty && !selectedStyle.isEmpty
    }

    var body: some View {
        ZStack {
            Color(red: 0.949, green: 0.933, blue: 0.914)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 28)

                    Text("Describe your style")
                        .font(.custom("Coolvetica",size: 26))
                        .foregroundStyle(.primary)
                        .padding(.bottom, 20)

                    // Gender Dropdown
                    FittyDropdown(
                        placeholder: selectedGender.isEmpty ? "i shop for…" : selectedGender,
                        isExpanded: $genderExpanded
                    ) {
                        ForEach(genderOptions, id: \.self) { option in
                            FittyRadioRow(
                                title: option,
                                isSelected: selectedGender == option
                            ) {
                                selectedGender = option
                                withAnimation(.spring(response: 0.3)) {
                                    genderExpanded = false
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)

                    // Style Dropdown
                    FittyDropdown(
                        placeholder: selectedStyle.isEmpty ? "my style is…" : selectedStyle,
                        isExpanded: $styleExpanded
                    ) {
                        ForEach(styleOptions, id: \.self) { option in
                            FittyRadioRow(
                                title: option,
                                isSelected: selectedStyle == option
                            ) {
                                selectedStyle = option
                                withAnimation(.spring(response: 0.3)) {
                                    styleExpanded = false
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 24)

                    Button(action: onContinue) {
                        Text("Next")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                canContinue
                                    ? Color(red: 0.847, green: 0.298, blue: 0.165)
                                    : Color(red: 0.847, green: 0.298, blue: 0.165).opacity(0.4),
                                in: Capsule()
                            )
                    }
                    .disabled(!canContinue)
                    .animation(.easeInOut(duration: 0.2), value: canContinue)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Dropdown Container

struct FittyDropdown<Content: View>: View {
    let placeholder: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(placeholder)
                        .font(.system(size: 15, weight: isExpanded ? .medium : .regular))
                        .foregroundStyle(isExpanded ? .primary : .secondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                content()
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Radio Row

struct FittyRadioRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.primary : Color(white: 0.78),
                            lineWidth: 1.5
                        )
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 10, height: 10)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isSelected)

                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Divider()
    }
}