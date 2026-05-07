import SwiftUI

struct HomeTab: View {
    let user: AppUser

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 50, height: 50)

                    Text("welcome, \(user.name.isEmpty ? "matthew" : user.name.lowercased())!")
                        .font(.title3.weight(.semibold))

                    Text("my friends")
                        .font(.headline)

                    HStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(Color.black.opacity(0.12))
                                .frame(width: 34, height: 34)
                        }
                    }

                    Text("your feed")
                        .font(.headline)
                        .padding(.top, 4)

                    HStack(spacing: 12) {
                        FeedFilterChip(title: "recent", isActive: true)
                        FeedFilterChip(title: "friends only")
                        FeedFilterChip(title: "saved")
                    }
                    .padding(.bottom, 2)

                    FeedPostPlaceholder(author: "vicky", followTitle: "following", showsTags: true)
                    FeedPostPlaceholder(author: "cecile", followTitle: "follow", showsTags: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Feed Supporting Views

struct FeedFilterChip: View {
    let title: String
    var isActive: Bool = false

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 29)
            .background(
                isActive ? Color.black.opacity(0.25) : Color.black.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 14.5, style: .continuous)
            )
    }
}

struct FeedPostPlaceholder: View {
    let author: String
    let followTitle: String
    let showsTags: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 33, height: 33)

                Text(author)
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(followTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 120, height: 33)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
                .frame(height: 373)

            HStack {
                Text("OOTD")
                    .font(.headline.weight(.semibold))
                Spacer()
                Image(systemName: "message")
                Image(systemName: "heart")
                Image(systemName: "bookmark")
            }
            .font(.title3)

            Text("april 20, 2026")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("sacccacsasakccndndpwqjdpqwjdwjqpdjwqdwqdqwdqwndwqdd")
                .font(.caption2)
                .lineLimit(2)

            if showsTags {
                HStack(spacing: 8) {
                    Text("Brown Leather Belt")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("Black Top")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(.bottom, 10)
    }
}