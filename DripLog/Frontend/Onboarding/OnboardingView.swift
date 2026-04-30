//
//  OnboardingView.swift
//  DripLog
//
//  Onboarding/OnboardingView.swift
//

import SwiftUI

/// The three swipeable tutorial screens shown only to brand-new users.
/// Call `onFinish` when the user taps through the last page.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private let pages: [String] = [
        "Your closet,\nbut digital",
        "See your\nfriends' fits",
        "Get AI\noutfit inspo"
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.92, green: 0.92, blue: 0.92)
                .ignoresSafeArea()

            VStack(alignment: .leading) {

                // Progress bar
                HStack(spacing: 12) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Rectangle()
                            .fill(index <= pageIndex
                                  ? Color.black.opacity(0.3)
                                  : Color.black.opacity(0.15))
                            .frame(height: 3)
                    }
                }
                .padding(.top, 70)
                .padding(.horizontal, 40)

                Spacer()

                // Page text
                Text(pages[pageIndex])
                    .font(.system(size: 54, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .padding(.horizontal, 40)

                Spacer()

                // Next / Finish chevron
                HStack {
                    Spacer()
                    Button(action: advance) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 70, height: 70)
                            .background(
                                Color.black.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 54)
                    .padding(.bottom, 67)
                }
            }
        }
    }

    private func advance() {
        if pageIndex < pages.count - 1 {
            pageIndex += 1
        } else {
            onFinish()
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}