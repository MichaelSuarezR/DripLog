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
    @State private var profileToUnfollow: FriendProfile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var friendService: FriendServicing?

    private let backgroundColor = Color.white
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
        .confirmationDialog(
            "Are you sure you'd like to unfollow?",
            isPresented: Binding(
                get: { profileToUnfollow != nil },
                set: { isPresented in
                    if !isPresented {
                        profileToUnfollow = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Unfollow", role: .destructive) {
                if let profileToUnfollow {
                    Task { await unfollow(profileToUnfollow) }
                }
            }
            Button("Cancel", role: .cancel) {
                profileToUnfollow = nil
            }
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
                        FriendNameRow(
                            profile: friend,
                            actionBlue: actionBlue,
                            onProfileTap: {
                                selectedProfile = FriendSearchResult(profile: friend, hasSentRequest: true)
                            },
                            onUnfollow: {
                                profileToUnfollow = friend
                            }
                        )
                    }
                case .friendRequests:
                    ForEach(incomingRequests) { request in
                        FriendRequestRow(
                            request: request,
                            actionBlue: actionBlue,
                            onProfileTap: {
                                selectedProfile = FriendSearchResult(
                                    profile: request.user,
                                    hasSentRequest: request.isFollowingBack || sentRequestIDs.contains(request.user.id)
                                )
                            },
                            onFollowBack: {
                                Task { await followBack(request) }
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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not search accounts."
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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not follow this account."
        }
    }

    private func followBack(_ request: FriendRequest) async {
        guard !request.isFollowingBack else { return }

        do {
            try await service().acceptFriendRequest(from: request.user.id, to: user.id)
            incomingRequests = incomingRequests.map { existing in
                guard existing.id == request.id else { return existing }
                return FriendRequest(id: existing.id, user: existing.user, isFollowingBack: true)
            }
            await loadFriends()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not follow back."
        }
    }

    private func unfollow(_ profile: FriendProfile) async {
        profileToUnfollow = nil

        do {
            try await service().unfollow(from: user.id, to: profile.id)
            friends.removeAll { $0.id == profile.id }
            sentRequestIDs.remove(profile.id)
            searchResults = searchResults.map { result in
                guard result.profile.id == profile.id else { return result }
                return FriendSearchResult(profile: result.profile, hasSentRequest: false)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not unfollow this account."
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
            "Following"
        case .friendRequests:
            "Followers"
        case .findFriends:
            "Find\nFriends"
        }
    }
}

private struct FriendNameRow: View {
    let profile: FriendProfile
    let actionBlue: Color
    let onProfileTap: () -> Void
    let onUnfollow: () -> Void

    var body: some View {
        HStack(spacing: 14) {
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

            Button("Unfollow", action: onUnfollow)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 85, height: 39)
                .background(actionBlue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .buttonStyle(.plain)
        }
        .frame(height: 65)
    }
}

private struct FriendRequestRow: View {
    let request: FriendRequest
    let actionBlue: Color
    let onProfileTap: () -> Void
    let onFollowBack: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onProfileTap) {
                HStack(spacing: 16) {
                    FriendAvatar(url: request.user.avatarURL)

                    Text(request.user.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(request.isFollowingBack ? "Following" : "Follow Back", action: onFollowBack)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 100, height: 39)
                .background(request.isFollowingBack ? Color(hex: 0x9BB3E1) : actionBlue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(request.isFollowingBack)
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

            Button(isSent ? "Following" : "Follow", action: onAdd)
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

struct FriendProfileDetailView: View {
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
    @State private var selectedOutfit: OutfitPhoto?

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
        .fullScreenCover(item: $selectedOutfit) { outfit in
            FriendPostDetailView(
                outfit: outfit,
                onBack: {
                    selectedOutfit = nil
                }
            )
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            FriendAvatar(url: profile.avatarURL, size: 80)

            Text(profile.name)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.black)

            ZStack(alignment: .leading) {
                Button {
                    Task { await follow() }
                } label: {
                    Text((isSent || didSendFollow) ? "Following" : "Follow")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 218, height: 45)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSent || didSendFollow || isSendingFollow)
                .opacity(isSendingFollow ? 0.7 : 1)

                Image("followbuddy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 60)
                    .offset(x: -48)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var outfitGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(outfits) { outfit in
                Button {
                    selectedOutfit = outfit
                } label: {
                    Color.black.opacity(0.08)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            GeometryReader { proxy in
                                CachedAsyncImage(url: outfit.imageURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                }
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
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

private struct FriendPostDetailView: View {
    let outfit: OutfitPhoto
    let onBack: () -> Void

    private static let titleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.titleDateFormatter.string(from: outfit.createdAt))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)

                    Color.black.opacity(0.08)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            GeometryReader { proxy in
                                CachedAsyncImage(url: outfit.imageURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                }
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .padding(.top, 20)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(captionText)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.black)

                            Text(Self.detailDateFormatter.string(from: outfit.createdAt))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: 0x9BB3E1))
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Image(systemName: "heart")
                            Image(systemName: "bookmark")
                        }
                        .font(.system(size: 35, weight: .regular))
                        .foregroundStyle(.black)
                    }
                    .padding(.top, 11)

                    if !outfit.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(outfit.tags.prefix(6), id: \.self) { tag in
                                    Text(tag.capitalized)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .frame(height: 34)
                                        .background(
                                            Color(hex: 0x9BB3E1),
                                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        )
                                }
                            }
                        }
                        .padding(.top, 11)
                    }
                }
                .padding(.horizontal, 31)
                .padding(.bottom, 70)
            }

            Button("Back", action: onBack)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
                .buttonStyle(.plain)
                .padding(.leading, 31)
                .padding(.top, 42)
        }
    }

    private var captionText: String {
        if !outfit.customTags.isEmpty {
            return outfit.customTags.joined(separator: ", ")
        }

        return "just posted a fit."
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
