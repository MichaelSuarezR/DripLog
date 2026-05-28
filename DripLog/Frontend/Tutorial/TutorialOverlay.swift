// TutorialOverlay.swift
// Place in: Frontend/Tutorial/TutorialOverlay.swift

import SwiftUI

struct TutorialOverlay: View {
    @EnvironmentObject var tutorial: TutorialManager

    let step: TutorialStep
    let title: String
    let message: String
    let anchorFrame: CGRect?

    private let tooltipWidth: CGFloat = 250

    var body: some View {
        guard tutorial.isActive && tutorial.currentStep == step else {
            return AnyView(EmptyView())
        }

        return AnyView(
            ZStack {
                // Dimming layer
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)

                // Spotlight cutout
                if let frame = anchorFrame {
                    SpotlightCutout(rect: frame.insetBy(dx: -6, dy: -6))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // Tooltip
                tooltipBubble
            }
        )
    }

    private var tooltipBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Coolvetica", size: 18))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        tutorial.advance()
                    }
                } label: {
                    Text(step == .feed ? "Got it!" : "Next")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: tooltipWidth)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.22, green: 0.33, blue: 0.72).opacity(0.95))
        )
        .position(tooltipPosition)
    }

    private var tooltipPosition: CGPoint {
        let screen = UIScreen.main.bounds
        let tooltipHeight: CGFloat = 150
        let margin: CGFloat = 20

        guard let frame = anchorFrame else {
            return CGPoint(x: screen.midX, y: screen.midY)
        }

        let x = min(
            max(tooltipWidth / 2 + margin, frame.midX),
            screen.width - tooltipWidth / 2 - margin
        )

        let spaceBelow = screen.height - frame.maxY
        let y: CGFloat
        if spaceBelow > tooltipHeight + 32 {
            y = frame.maxY + 16 + tooltipHeight / 2
        } else {
            y = frame.minY - 16 - tooltipHeight / 2
        }

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Spotlight Shape

struct SpotlightCutout: View {
    let rect: CGRect

    var body: some View {
        SpotlightShape(rect: rect)
            .fill(style: FillStyle(eoFill: true))
            .foregroundStyle(Color.black.opacity(0.5))
    }
}

private struct SpotlightShape: Shape {
    let rect: CGRect

    func path(in bounds: CGRect) -> Path {
        var path = Rectangle().path(in: UIScreen.main.bounds)
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: 12, height: 12)
        )
        return path
    }
}