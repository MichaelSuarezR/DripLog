import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    private let barWidth: CGFloat = 334
    private let barHeight: CGFloat = 59

    var body: some View {
        ZStack(alignment: .top) {
            Image("CustomTabBarBackground")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: barWidth, height: barHeight)

            HStack {
                tabButton(imageName: "ClosetTabIcon", tab: .closet)
                Spacer()
                tabButton(imageName: "FeedTabIcon", tab: .feed)
            }
            .padding(.horizontal, 52)
            .frame(width: barWidth, height: barHeight)

            Button {
                selectedTab = .add
            } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image("AddTabIcon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(iconColor(for: .add))
                    }
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            }
            .offset(y: -6)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
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
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: tab == .closet ? 18 : 21, height: 18)
                .foregroundStyle(iconColor(for: tab))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconColor(for tab: AppTab) -> Color {
        selectedTab == tab
            ? Color(red: 0.08, green: 0.34, blue: 0.27)
            : Color(red: 0.42, green: 0.45, blue: 0.50)
    }
}