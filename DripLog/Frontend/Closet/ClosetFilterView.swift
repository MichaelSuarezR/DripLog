import SwiftUI

struct ClosetFilterView: View {
    @Binding var filters: ClosetFilters
    @Environment(\.dismiss) private var dismiss

    @State private var visibility: OutfitVisibility = .privateProfile

    var body: some View {
        NavigationStack {
            TagEditorView(
                configuration: .filter,
                filters: $filters,
                heroImage: nil,
                visibility: $visibility,
                leadingHeaderAction: TagEditorHeaderAction(title: "", systemImage: "xmark.circle") {
                    dismiss()
                }
            )
            .modalEntryTransition()
        }
    }
}
