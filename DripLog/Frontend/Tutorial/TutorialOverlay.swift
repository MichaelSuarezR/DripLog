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
                // REMOVED: Standalone dimming layer that was doubling the opacity

                // Spotlight cutout handles both the background dimming AND the clear cutout
                if let frame = anchorFrame {
                    SpotlightCutout(rect: frame.insetBy(dx: -14, dy: -14))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                } else {
                    // Fallback dim background if there's no specific element to anchor to
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()
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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(red: 0.588, green: 0.678, blue: 0.839).opacity(0.95))
        )
        .position(tooltipPosition)
    }

    private var tooltipPosition: CGPoint {
        let screen = UIScreen.main.bounds
        let tooltipHeight: CGFloat = 150
        let margin: CGFloat = 20
        let safeTop: CGFloat = 60

        guard let frame = anchorFrame else {
            return CGPoint(x: screen.midX, y: screen.midY)
        }

        let x = min(
            max(tooltipWidth / 2 + margin, frame.midX),
            screen.width - tooltipWidth / 2 - margin
        )

        let spaceBelow = screen.height - frame.maxY
        var y: CGFloat
        if spaceBelow > tooltipHeight + 32 {
            y = frame.maxY + 16 + tooltipHeight / 2
        } else {
            y = frame.minY - 16 - tooltipHeight / 2
        }

        y = max(y, safeTop + tooltipHeight / 2)
        y = min(y, screen.height - tooltipHeight / 2 - margin)

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Spotlight Shape

struct SpotlightCutout: View {
    let rect: CGRect

    var body: some View {
        Canvas { context, size in
            let fullRect = Path(CGRect(origin: .zero, size: size))
            let spotlight = Path(roundedRect: rect, cornerRadius: 12)

            // ADJUST HERE: Changed opacity from 0.5 to 0.65 to make the surrounding screen
            // darker, which makes the bright spotlighted center pop out much more.
            context.fill(fullRect, with: .color(.black.opacity(0.65)))
            
            // This cleanly cuts through the single dark layer above
            context.blendMode = .clear
            context.fill(spotlight, with: .color(.black))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}