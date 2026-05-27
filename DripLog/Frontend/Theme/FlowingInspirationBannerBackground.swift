import SwiftUI

/// Animated rainbow gradient border used on AI-powered buttons.
struct AIRainbowBorderView: View {
    var cornerRadius: CGFloat = 16
    var lineWidth: CGFloat = 2.5

    private let rainbowColors: [Color] = [
        Color(hex: 0xFF6B6B),
        Color(hex: 0xFFA94D),
        Color(hex: 0xFFD93D),
        Color(hex: 0x6BCB77),
        Color(hex: 0x4D96FF),
        Color(hex: 0x9B59B6),
        Color(hex: 0xE84393),
        Color(hex: 0xFF6B6B),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let degrees = (t / 3).truncatingRemainder(dividingBy: 1) * 360

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: rainbowColors,
                        center: .center,
                        angle: .degrees(degrees)
                    ),
                    lineWidth: lineWidth
                )
        }
        .drawingGroup()
    }
}
