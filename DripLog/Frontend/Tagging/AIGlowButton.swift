import SwiftUI

struct AIGlowButton: View {
    let title: String
    @Binding var isLoading: Bool
    let action: () async -> Void

    @State private var rotation: Double = 0
    @State private var glowOpacity: Double = 0.55

    private let glowColors: [Color] = [
        AppColor.loadingBlue,
        AppColor.lavender,
        AppColor.accentOrange,
        AppColor.loadingBlue
    ]

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            ZStack {
                glowBackground
                    .opacity(isLoading ? glowOpacity : 0.55)

                Text(title)
                    .font(AppFont.uiRegular(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 24)
                    .background(AppColor.placeholderBlue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onChange(of: isLoading) { _, loading in
            if loading {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.7
                }
            } else {
                glowOpacity = 0.55
            }
        }
    }

    private var glowBackground: some View {
        AngularGradient(colors: glowColors, center: .center, angle: .degrees(rotation))
            .blur(radius: 18)
            .opacity(0.55)
            .padding(-6)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
