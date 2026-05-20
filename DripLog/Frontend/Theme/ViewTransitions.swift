import SwiftUI

extension AnyTransition {
    static var modalEntry: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.96))
    }
}

struct ModalEntryTransitionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.modalEntry)
    }
}

extension View {
    func modalEntryTransition() -> some View {
        modifier(ModalEntryTransitionModifier())
    }
}
