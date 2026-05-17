import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    private let barWidth: CGFloat = 334
    private let barHeight: CGFloat = 58
    private let selectedBlue = Color(red: 0.60, green: 0.70, blue: 0.88)

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(Color.white)
                .frame(width: barWidth, height: barHeight)
                .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)

            HStack {
                tabButton(imageName: "ClosetTabIcon", tab: .closet)
                Spacer()
                tabButton(imageName: "FeedTabIcon", tab: .feed)
            }
            .padding(.horizontal, 27)
            .frame(width: barWidth, height: barHeight)

            Button {
                selectedTab = .add
            } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 66, height: 66)
                    .overlay {
                        Image("AddTabIcon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundStyle(Color.black)
                    }
                    .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 4)
            }
            .offset(y: -46)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 19)
        .background(alignment: .bottom) {
            Color.white
                .frame(height: 24)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(imageName: String, tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            ZStack {
                if selectedTab == tab {
                    Capsule(style: .continuous)
                        .fill(selectedBlue)
                        .frame(width: 97, height: 42)
                }

                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: tab == .closet ? 38 : 38,
                        height: tab == .closet ? 38 : 32
                    )
                    .foregroundStyle(Color.black)
            }
            .frame(width: 120, height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
