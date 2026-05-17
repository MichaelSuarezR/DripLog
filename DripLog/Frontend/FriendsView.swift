import SwiftUI

struct FriendsView: View {
    let user: AppUser
    let onClose: () -> Void

    @State private var selectedTab: FriendsTab = .friends
    @State private var searchText = ""
    @State private var friends: [FriendProfile] = []
    @State private var incomingRequests: [FriendRequest] = []
    @State private var searchResults: [FriendSearchResult] = []
    @State private var sentRequestIDs: Set<UUID> = []
    @State private var selectedProfile: FriendSearchResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var friendService: FriendServicing?

    private let backgroundColor = Color(hex: 0xF2EEE9)
    private let activeColor = Color(hex: 0xE4432D)
    private let actionBlue = Color(hex: 0x43A3C7)
    private let borderColor = Color.black.opacity(0.18)

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundColor
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topSpacer
                    segmentedTabs

                    if selectedTab == .findFriends {
                        searchBar
                            .padding(.top, 22)
                    }

                    listContent
                        .padding(.top, selectedTab == .findFriends ? 24 : 47)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .padding(.top, 18)
                    }
                }
                .padding(.bottom, 36)
            }

            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(width: 58, height: 58)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .padding(.leading, 20)
            .padding(.top, 12)
        }
        .task {
            await reloadCurrentTab()
        }
        .onChange(of: selectedTab) { _, _ in
            Task {
                await reloadCurrentTab()
            }
        }
        .onChange(of: searchText) { _, _ in
            guard selectedTab == .findFriends else { return }
            Task {
                await searchUsers()
            }
        }
        .fullScreenCover(item: $selectedProfile) { result in
            FriendProfileDetailView(
                profile: result.profile,
                isSent: result.hasSentRequest || sentRequestIDs.contains(result.profile.id),
                onBack: {
                    selectedProfile = nil
                },
                onFollow: {
                    await sendRequest(to: result.profile)
                }
            )
        }
    }

    private var topSpacer: some View {
        Color.clear
            .frame(height: 62)
    }

    private var segmentedTabs: some View {
        HStack(spacing: 0) {
            ForEach(FriendsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(selectedTab == tab ? .white : .black)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            selectedTab == tab ? activeColor : Color.white,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .shadow(
                            color: selectedTab == tab ? .black.opacity(0.20) : .clear,
                            radius: 5,
                            x: 0,
                            y: 4
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 54)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selectedTab == .friends ? Color.clear : borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 13)
    }

    private var searchBar: some View {
        HStack(spacing: 13) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(.black)

            TextField("Find a Friend", text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.black)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 18)
        .frame(height: 50)
        .background(Color(hex: 0xD9D9D9), in: Capsule())
        .padding(.horizontal, 14)
    }

    private var listContent: some View {
        VStack(spacing: selectedTab == .findFriends ? 44 : 46) {
            if isLoading {
                ProgressView()
                    .padding(.top, 26)
            } else {
                switch selectedTab {
                case .friends:
                    ForEach(friends) { friend in
                        FriendNameRow(profile: friend)
                    }
                case .friendRequests:
                    ForEach(incomingRequests) { request in
                        FriendRequestRow(
                            request: request,
                            actionBlue: actionBlue,
                            onAccept: {
                                Task { await accept(request) }
                            },
                            onDecline: {
                                Task { await decline(request) }
                            }
                        )
                    }
                case .findFriends:
                    ForEach(searchResults) { result in
                        FindFriendRow(
                            profile: result.profile,
                            actionBlue: actionBlue,
                            isSent: result.hasSentRequest || sentRequestIDs.contains(result.profile.id),
                            onProfileTap: {
                                selectedProfile = result
                            },
                            onAdd: {
                                Task { await sendRequest(to: result.profile) }
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, selectedTab == .friends ? 31 : 30)
    }

    private func reloadCurrentTab() async {
        switch selectedTab {
        case .friends:
            await loadFriends()
        case .friendRequests:
            await loadIncomingRequests()
        case .findFriends:
            await searchUsers()
        }
    }

    private func loadFriends() async {
        await runLoading {
            friends = try await service().fetchFriends(for: user.id)
        }
    }

    private func loadIncomingRequests() async {
        await runLoading {
            incomingRequests = try await service().fetchIncomingRequests(for: user.id)
        }
    }

    private func searchUsers() async {
        errorMessage = nil

        do {
            searchResults = try await service().searchUsers(matching: searchText, currentUserID: user.id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not search friends."
        }
    }

    private func sendRequest(to profile: FriendProfile) async {
        guard !sentRequestIDs.contains(profile.id) else { return }

        do {
            try await service().sendFriendRequest(from: user.id, to: profile.id)
            sentRequestIDs.insert(profile.id)
            searchResults = searchResults.map { result in
                guard result.profile.id == profile.id else { return result }
                return FriendSearchResult(profile: result.profile, hasSentRequest: true)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not send friend request."
        }
    }

    private func accept(_ request: FriendRequest) async {
        do {
            try await service().acceptFriendRequest(request.id)
            incomingRequests.removeAll { $0.id == request.id }
            await loadFriends()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not accept friend request."
        }
    }

    private func decline(_ request: FriendRequest) async {
        do {
            try await service().declineFriendRequest(request.id)
            incomingRequests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not decline friend request."
        }
    }

    private func runLoading(_ operation: () async throws -> Void) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not load friends."
        }
    }

    private func service() throws -> FriendServicing {
        if let friendService { return friendService }
        let createdService = try SupabaseFriendService()
        friendService = createdService
        return createdService
    }
}

private enum FriendsTab: CaseIterable, Identifiable {
    case friends
    case friendRequests
    case findFriends

    var id: Self { self }

    var title: String {
        switch self {
        case .friends:
            "Friends"
        case .friendRequests:
            "Friend\nRequests"
        case .findFriends:
            "Find\nFriends"
        }
    }
}

private struct FriendNameRow: View {
    let profile: FriendProfile

    var body: some View {
        HStack(spacing: 17) {
            FriendAvatar(url: profile.avatarURL)
            Text(profile.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
            Spacer()
        }
        .frame(height: 65)
    }
}

private struct FriendRequestRow: View {
    let request: FriendRequest
    let actionBlue: Color
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            FriendAvatar(url: request.user.avatarURL)

            Text(request.user.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)

            Spacer()

            Button("Accept", action: onAccept)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 77, height: 41)
                .background(actionBlue, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Button(action: onDecline) {
                Image(systemName: "xmark")
                    .font(.system(size: 25, weight: .regular))
                    .foregroundStyle(.black)
                    .frame(width: 31, height: 41)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 65)
    }
}

private struct FindFriendRow: View {
    let profile: FriendProfile
    let actionBlue: Color
    let isSent: Bool
    let onProfileTap: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 17) {
            Button(action: onProfileTap) {
                HStack(spacing: 17) {
                    FriendAvatar(url: profile.avatarURL)

                    Text(profile.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(isSent ? "Added" : "Add", action: onAdd)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 85, height: 39)
                .background(actionBlue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(isSent)
                .buttonStyle(.plain)
        }
        .frame(height: 65)
    }
}

private struct FriendProfileDetailView: View {
    let profile: FriendProfile
    let isSent: Bool
    let onBack: () -> Void
    let onFollow: () async -> Void

    @State private var outfits: [OutfitPhoto] = []
    @State private var isLoading = false
    @State private var isSendingFollow = false
    @State private var didSendFollow = false
    @State private var errorMessage: String?
    @State private var outfitService: OutfitServicing?

    private let columns = [
        GridItem(.flexible(), spacing: 36),
        GridItem(.flexible(), spacing: 36)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHeader

                    if isLoading {
                        ProgressView()
                            .padding(.top, 32)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 24)
                    } else {
                        outfitGrid
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 44)
                .padding(.bottom, 60)
            }

            Button("Back", action: onBack)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
                .buttonStyle(.plain)
                .padding(.leading, 40)
                .padding(.top, 46)
        }
        .task {
            await loadOutfits()
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            FriendAvatar(url: profile.avatarURL, size: 80)

            Text(profile.name)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.black)

            Button {
                Task { await follow() }
            } label: {
                Text((isSent || didSendFollow) ? "Sent" : "Follow")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 218, height: 45)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSent || didSendFollow || isSendingFollow)
            .opacity(isSendingFollow ? 0.7 : 1)
        }
        .frame(maxWidth: .infinity)
    }

    private var outfitGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(outfits) { outfit in
                CachedAsyncImage(url: outfit.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                }
                .frame(height: 232)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .clipped()
            }
        }
    }

    private func follow() async {
        guard !isSent, !didSendFollow, !isSendingFollow else { return }
        isSendingFollow = true
        defer { isSendingFollow = false }

        await onFollow()
        didSendFollow = true
    }

    private func loadOutfits() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            outfits = try await service().fetchOutfits(for: profile.id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not load outfits."
        }
    }

    private func service() throws -> OutfitServicing {
        if let outfitService { return outfitService }
        let createdService = try SupabaseOutfitService()
        outfitService = createdService
        return createdService
    }
}

private struct FriendAvatar: View {
    let url: URL?
    var size: CGFloat = 65

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Circle()
                            .fill(Color(hex: 0xD9D9D9))
                    }
                }
            } else {
                Circle()
                    .fill(Color(hex: 0xD9D9D9))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

#Preview {
    FriendsView(user: AppUser(id: UUID(), name: "Michael", email: "michael@example.com"), onClose: {})
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
