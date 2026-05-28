// TutorialAnchorKey.swift
// Place in: Frontend/Tutorial/TutorialAnchorKey.swift

import SwiftUI

struct TutorialAnchorData: Equatable {
    let step: TutorialStep
    let frame: CGRect
}

struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [TutorialAnchorData] = []
    static func reduce(value: inout [TutorialAnchorData], nextValue: () -> [TutorialAnchorData]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func tutorialAnchor(step: TutorialStep) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: TutorialAnchorKey.self,
                        value: [TutorialAnchorData(
                            step: step,
                            frame: geo.frame(in: .global)
                        )]
                    )
            }
        )
    }
}