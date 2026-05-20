import PhotosUI
import SwiftUI
import UIKit

struct OnboardingPhotoGridView: View {
    let profileSlot: OnboardingSlotState
    let outfitSlots: [OnboardingSlotState]
    var heroNamespace: Namespace.ID? = nil
    var activeHeroSlotID: String? = nil
    let canFinish: Bool
    let isFinishing: Bool
    let onPickProfile: (PhotosPickerItem) -> Void
    let onPickOutfit: (Int, PhotosPickerItem) -> Void
    let onTapUploadedOutfit: (Int) -> Void
    let onFinish: () -> Void

    @State private var profilePickerItem: PhotosPickerItem?
    @State private var outfitPickerItems: [Int: PhotosPickerItem] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Upload your photos")
                    .font(AppFont.uiBold(size: 40))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.top, 48)

                Text("Start by uploading a profile photo and 5 outfits to begin")
                    .font(AppFont.uiRegular(size: 14))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                photoGrid
                    .padding(.horizontal, 32)
                    .padding(.top, 36)

                if canFinish {
                    Button(action: onFinish) {
                        Text(isFinishing ? "Finishing..." : "Continue")
                            .font(AppFont.uiRegular(size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppColor.accentOrange, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isFinishing)
                    .padding(.horizontal, 48)
                    .padding(.top, 32)
                    .padding(.bottom, 48)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .background(AppColor.cream.ignoresSafeArea())
        .onChange(of: profilePickerItem) { _, item in
            guard let item else { return }
            onPickProfile(item)
            profilePickerItem = nil
        }
    }

    private var photoGrid: some View {
        let spacing: CGFloat = 14

        return VStack(spacing: spacing) {
            HStack(alignment: .top, spacing: spacing) {
                profileSlotView
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)

                VStack(spacing: spacing) {
                    outfitSlotView(at: 0)
                    outfitSlotView(at: 1)
                }
                .frame(width: 110)
            }

            HStack(spacing: spacing) {
                ForEach(2..<5, id: \.self) { index in
                    outfitSlotView(at: index)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private var profileSlotView: some View {
        PhotosPicker(selection: $profilePickerItem, matching: .images) {
            slotContent(
                slot: profileSlot,
                label: "Add profile photo",
                isLarge: true
            )
        }
        .buttonStyle(.plain)
    }

    private func outfitSlotView(at index: Int) -> some View {
        let slot = outfitSlots[index]
        let pickerBinding = Binding<PhotosPickerItem?>(
            get: { outfitPickerItems[index] },
            set: { outfitPickerItems[index] = $0 }
        )

        return Group {
            if slot.didUpload {
                Button {
                    onTapUploadedOutfit(index)
                } label: {
                    slotContent(slot: slot, label: "Add", isLarge: false)
                }
                .buttonStyle(.plain)
            } else {
                PhotosPicker(selection: pickerBinding, matching: .images) {
                    slotContent(slot: slot, label: "Add", isLarge: false)
                }
                .buttonStyle(.plain)
                .onChange(of: outfitPickerItems[index]) { _, item in
                    guard let item else { return }
                    onPickOutfit(index, item)
                    outfitPickerItems[index] = nil
                }
            }
        }
    }

    private func slotContent(slot: OnboardingSlotState, label: String, isLarge: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: isLarge ? 28 : 22, style: .continuous)
                .fill(Color.black.opacity(0.08))

            if let image = slot.image {
                let thumbnail = Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: slot.isUploading ? 2.5 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: isLarge ? 28 : 22, style: .continuous))

                if let heroNamespace, slot.id == activeHeroSlotID {
                    thumbnail
                        .matchedGeometryEffect(id: slot.id, in: heroNamespace, properties: .frame, isSource: true)
                } else {
                    thumbnail
                }
            }

            if slot.isUploading {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                Spacer()
                Text(label)
                    .font(AppFont.uiRegular(size: isLarge ? 10 : 10))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white, in: Capsule())
                    .padding(.bottom, 10)
            }

            if let error = slot.errorMessage {
                VStack {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(6)
                    Spacer()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct OnboardingSlotState: Identifiable {
    enum Kind: Hashable {
        case profile
        case outfit(Int)
    }

    let kind: Kind
    var image: UIImage?
    var isUploading = false
    var didUpload = false
    var errorMessage: String?
    var uploadedOutfitID: UUID?

    var id: String {
        switch kind {
        case .profile: return "profile"
        case .outfit(let index): return "outfit-\(index)"
        }
    }
}
