import SwiftUI

/// Full-bleed animated gradient for AI / inspiration CTAs (closet banner, etc.).
struct FlowingInspirationBannerBackground: View {
    var cornerRadius: CGFloat = 42

    private let coreColors: [Color] = [
        AppColor.loadingBlue,
        AppColor.lavender,
        AppColor.accentOrange.opacity(0.92),
        Color(hex: 0x5A8FAF),
        AppColor.lavender.opacity(0.88),
        AppColor.loadingBlue
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 45, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let spinDegrees = (t / 14).truncatingRemainder(dividingBy: 1) * 360
            let wobble = sin(t * 0.55) * 0.08
            let sweep = sin(t * 0.9) * 0.35

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        AngularGradient(
                            colors: coreColors,
                            center: UnitPoint(x: 0.48 + wobble, y: 0.52 - wobble * 0.5),
                            angle: .degrees(spinDegrees)
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.28),
                                .clear,
                                .white.opacity(0.12),
                                .clear,
                                .white.opacity(0.18)
                            ],
                            startPoint: UnitPoint(x: 0.15 + sweep, y: 0),
                            endPoint: UnitPoint(x: 0.85 - sweep, y: 1)
                        )
                    )
                    .blendMode(.softLight)
            }
        }
        .drawingGroup()
    }
}
