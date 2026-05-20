import SwiftUI

struct OnboardingView: View {
    @Binding var pageIndex: Int
    let onAdvanceFromLastPage: () -> Void

    private let pages: [(text: String, color: Color, image: String)] = [
        ("Your Closet,\nBut Digital.", AppColor.loadingBlue, "OnboardingIllustration1"),
        ("See Your\nFriends' Fits.", AppColor.accentOrange, "OnboardingIllustration1"),
        ("Get AI\nOutfit Inspo.", AppColor.lavender, "OnboardingIllustration1"),
    ]

    var body: some View {
        ZStack {
            pages[pageIndex].color
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= pageIndex ? Color.white : Color.white.opacity(0.4))
                            .frame(height: 3)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 32)
                .animation(AppAnimation.standardSpring, value: pageIndex)

                Spacer()

                Text(pages[pageIndex].text)
                    .font(AppFont.logo(size: 52))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .id("headline-\(pageIndex)")
                    .transition(slideTransition)

                Spacer()

                Image(pages[pageIndex].image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .id("image-\(pageIndex)")
                    .transition(slideTransition)

                Spacer()

                HStack {
                    Spacer()
                    Button(action: advance) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 64, height: 64)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 32)
                    .padding(.bottom, 60)
                }
            }
        }
        .animation(AppAnimation.standardSpring, value: pageIndex)
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        if pageIndex < pages.count - 1 {
            withAnimation(AppAnimation.standardSpring) {
                pageIndex += 1
            }
        } else {
            onAdvanceFromLastPage()
        }
    }
}
