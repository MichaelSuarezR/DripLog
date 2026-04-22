//
//  HomeView.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import SwiftUI
import UIKit

struct HomeView: View {
    let user: AppUser
    let onLogOut: () -> Void

    @State private var selectedTab: AppTab = .home
    @State private var outfitPhotos: [OutfitPhoto] = []
    @State private var outfitErrorMessage: String?
    @State private var isUploadingOutfit = false
    @State private var didLoadOutfits = false
    @State private var outfitService: OutfitServicing?

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTab(user: user)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            CreateTab(
                isUploading: isUploadingOutfit,
                errorMessage: outfitErrorMessage,
                onCapture: uploadOutfit
            )
            .tabItem {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .tag(AppTab.add)

            ProfileTab(user: user, outfitPhotos: outfitPhotos, onLogOut: onLogOut)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(Color(red: 0.08, green: 0.34, blue: 0.27))
        .task {
            await loadOutfitsIfNeeded()
        }
    }

    private func loadOutfitsIfNeeded() async {
        guard !didLoadOutfits else { return }
        didLoadOutfits = true

        do {
            outfitPhotos = try await service().fetchOutfits(for: user.id)
        } catch {
            outfitErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not load saved outfits."
        }
    }

    private func uploadOutfit(_ image: UIImage) {
        Task {
            isUploadingOutfit = true
            outfitErrorMessage = nil
            defer { isUploadingOutfit = false }

            do {
                let photo = try await service().uploadOutfit(image, for: user.id)
                outfitPhotos.insert(photo, at: 0)
                selectedTab = .profile
            } catch {
                outfitErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not save outfit photo."
                selectedTab = .add
            }
        }
    }

    private func service() throws -> OutfitServicing {
        if let outfitService {
            return outfitService
        }

        let createdService = try SupabaseOutfitService()
        outfitService = createdService
        return createdService
    }
}

private enum AppTab {
    case home
    case add
    case profile
}

private struct HomeTab: View {
    let user: AppUser

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Welcome\(user.name.isEmpty ? "" : ", \(user.name)")")
                    .font(.largeTitle.bold())

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .navigationTitle("Home")
        }
    }
}

private struct CreateTab: View {
    let isUploading: Bool
    let errorMessage: String?
    let onCapture: (UIImage) -> Void

    @State private var isCameraPresented = false
    @State private var cameraErrorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.27))

                    Text("Capture outfit")
                        .font(.largeTitle.bold())
                }

                Button(action: presentCamera) {
                    Label(isUploading ? "Saving..." : "Open Camera", systemImage: "camera")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color(red: 0.08, green: 0.34, blue: 0.27), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .disabled(isUploading)
                .opacity(isUploading ? 0.7 : 1)

                if isUploading {
                    ProgressView("Uploading outfit photo...")
                }

                if let cameraErrorMessage {
                    Text(cameraErrorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Add")
            .onAppear(perform: presentCamera)
            .fullScreenCover(isPresented: $isCameraPresented) {
                CameraCaptureView { image in
                    onCapture(image)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func presentCamera() {
        guard !isUploading else { return }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraErrorMessage = "Camera is not available on this device or simulator."
            return
        }

        cameraErrorMessage = nil
        isCameraPresented = true
    }
}

private struct ProfileTab: View {
    let user: AppUser
    let outfitPhotos: [OutfitPhoto]
    let onLogOut: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    profileHeader
                    outfitsSection

                    Button("Log Out", action: onLogOut)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.08, green: 0.34, blue: 0.27))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Profile")
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.27))

            VStack(alignment: .leading, spacing: 6) {
                Text(user.name.isEmpty ? "Profile" : user.name)
                    .font(.title.bold())

                Text(user.email)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var outfitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Outfits")
                .font(.title2.bold())

            if outfitPhotos.isEmpty {
                ContentUnavailableView(
                    "No outfits yet",
                    systemImage: "camera",
                    description: Text("Tap Add and take your first outfit photo.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(outfitPhotos) { photo in
                        Image(uiImage: photo.image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .clipped()
                    }
                }
            }
        }
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }

            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    HomeView(user: AppUser(id: UUID(), name: "Michael", email: "michael@example.com"), onLogOut: {})
}
