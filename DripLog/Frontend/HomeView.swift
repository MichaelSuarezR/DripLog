//
//  HomeView.swift
//  DripLog
//
//  Created by Michael Suarez-Russell on 4/21/26.
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import Combine

struct HomeView: View {
    let user: AppUser
    let onLogOut: () -> Void

    @State private var selectedTab: AppTab = .home
    @State private var pendingOutfitDraft: PendingOutfitDraft?
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
                onCapture: prepareOutfit
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
        .fullScreenCover(item: $pendingOutfitDraft) { draft in
            OutfitUploadTaggingView(
                image: draft.image,
                isSaving: isUploadingOutfit,
                onCancel: {
                    pendingOutfitDraft = nil
                },
                onSave: { tags in
                    uploadOutfit(draft.image, tags: tags)
                }
            )
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

    private func prepareOutfit(_ image: UIImage) {
        outfitErrorMessage = nil
        pendingOutfitDraft = PendingOutfitDraft(image: image)
    }

    private func uploadOutfit(_ image: UIImage, tags: [String]) {
        Task {
            isUploadingOutfit = true
            outfitErrorMessage = nil
            defer { isUploadingOutfit = false }

            do {
                let photo = try await service().uploadOutfit(image, tags: tags, for: user.id)
                outfitPhotos.insert(photo, at: 0)
                pendingOutfitDraft = nil
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

private struct PendingOutfitDraft: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct HomeTab: View {
    let user: AppUser

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your Feed")
                        .font(.largeTitle.bold())
                    
                    Text("Welcome\(user.name.isEmpty ? "" : ", \(user.name)")")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    ForEach(0..<4, id: \.self) { _ in
                        FeedPlaceholderCard()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Feed")
        }
    }
}

private struct FeedPlaceholderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 120, height: 14)
                
                Spacer()
            }
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.08))
                .frame(height: 280)
            
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.1))
                .frame(width: 220, height: 12)
            
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.1))
                .frame(width: 160, height: 12)
            
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct CreateTab: View {
    let isUploading: Bool
    let errorMessage: String?
    let onCapture: (UIImage) -> Void

    @State private var isCameraPresented = false
    @State private var cameraErrorMessage: String?
    @State private var capturedImage: UIImage?
    @State private var suppressAutoPresent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()

                if isUploading {
                    ProgressView("Uploading outfit photo...")
                }

                if let cameraErrorMessage {
                    Text(cameraErrorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
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

                Spacer()
            }
            .padding(24)
            .navigationTitle("Add")
            .onAppear {
                guard !suppressAutoPresent else {
                    suppressAutoPresent = false
                    return
                }

                presentCamera()
            }
            .fullScreenCover(isPresented: $isCameraPresented, onDismiss: handleCameraDismissed) {
                OutfitCameraView { image in
                    capturedImage = image
                    suppressAutoPresent = true
                    isCameraPresented = false
                }
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

    private func handleCameraDismissed() {
        guard let capturedImage else { return }
        let image = capturedImage
        self.capturedImage = nil
        onCapture(image)
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
                        VStack(alignment: .leading, spacing: 8) {
                            Image(uiImage: photo.image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .clipped()

                            if !photo.tags.isEmpty {
                                Text(photo.tags.joined(separator: ", "))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct OutfitUploadTaggingView: View {
    let image: UIImage
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: ([String]) -> Void

    @State private var tagInput = ""
    @State private var selectedTags: [String] = []

    private let suggestedTags = [
        "Black Top",
        "Dark Blue Jeans",
        "Red Scarf",
        "Flared Leggings",
        "White Sneakers",
        "Brown Leather Belt",
        "Black Hoodie",
        "Blue Denim Jacket",
        "Gray Sweatpants",
        "Gold Jewelry"
    ]

    private var filteredSuggestions: [String] {
        let normalizedInput = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedInput.isEmpty {
            return suggestedTags.filter { !selectedTags.contains($0) }
        }

        return suggestedTags.filter {
            !selectedTags.contains($0) && $0.localizedCaseInsensitiveContains(normalizedInput)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                promptRow
                tagChips
                Divider()
                    .padding(.top, 18)
                    .padding(.bottom, 16)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(filteredSuggestions, id: \.self) { tag in
                            Button(action: {
                                addTag(tag)
                            }) {
                                Text(tag)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .background(Color.white)
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.title3)
                .foregroundStyle(.black)

            Spacer()

            Text("Outfit Upload")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black)

            Spacer()

            Button("Save") {
                saveOutfit()
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.black)
            .disabled(isSaving)
            .opacity(isSaving ? 0.6 : 1)
        }
        .padding(.bottom, 22)
    }

    private var promptRow: some View {
        HStack(alignment: .top, spacing: 16) {
            TextField("What are you wearing?", text: $tagInput)
                .font(.title3)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit {
                    addTag(tagInput)
                }

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipped()
        }
    }

    @ViewBuilder
    private var tagChips: some View {
        if !selectedTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedTags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text(tag)
                                .font(.subheadline.weight(.medium))
                            Button {
                                selectedTags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.systemGray6), in: Capsule())
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private func addTag(_ rawTag: String) {
        let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        guard !selectedTags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else {
            tagInput = ""
            return
        }

        selectedTags.append(tag)
        tagInput = ""
    }

    private func saveOutfit() {
        let trimmedInput = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTags: [String]

        if
            !trimmedInput.isEmpty,
            !selectedTags.contains(where: { $0.caseInsensitiveCompare(trimmedInput) == .orderedSame })
        {
            finalTags = selectedTags + [trimmedInput]
        } else {
            finalTags = selectedTags
        }

        onSave(finalTags)
    }
}

private struct OutfitCameraView: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraController = CameraSessionController()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoadingLibraryImage = false
    @State private var isFlashEnabled = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraController.session)
                .ignoresSafeArea()
                .overlay {
                    if !cameraController.isReady {
                        Color.black
                            .overlay {
                                if let errorMessage = cameraController.errorMessage {
                                    Text(errorMessage)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(24)
                                } else {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                    }
                }

            VStack {
                HStack {
                    circularControlButton(systemImage: "chevron.left", action: { dismiss() })
                    Spacer()
                    circularControlButton(systemImage: "ellipsis", action: {})
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)

                Spacer()

                if isLoadingLibraryImage {
                    ProgressView()
                        .tint(.white)
                        .padding(.bottom, 16)
                }

                HStack {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        controlCircle(systemImage: "photo.on.rectangle")
                    }
                    .disabled(isLoadingLibraryImage)

                    Spacer()

                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 76, height: 76)
                            Circle()
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                .frame(width: 76, height: 76)
                        }
                    }
                    .disabled(!cameraController.isReady || isLoadingLibraryImage)

                    Spacer()

                    Button(action: toggleFlash) {
                        Circle()
                            .fill(isFlashEnabled ? Color.white.opacity(0.82) : Color.white.opacity(0.18))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(isFlashEnabled ? Color.black.opacity(0.78) : .white)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!cameraController.isFlashAvailable || isLoadingLibraryImage)
                    .opacity(cameraController.isFlashAvailable ? 1 : 0.45)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal, 30)
                .padding(.bottom, 28)
            }
        }
        .task {
            await cameraController.start()
        }
        .onDisappear {
            cameraController.stop()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            loadSelectedPhoto(from: newItem)
        }
    }

    private func capturePhoto() {
        cameraController.capturePhoto(flashMode: isFlashEnabled ? .on : .off) { image in
            onCapture(image)
        }
    }

    private func toggleFlash() {
        guard cameraController.isFlashAvailable else { return }
        isFlashEnabled.toggle()
    }

    private func loadSelectedPhoto(from item: PhotosPickerItem) {
        isLoadingLibraryImage = true

        Task {
            defer { isLoadingLibraryImage = false }

            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                return
            }

            onCapture(image)
        }
    }

    private func circularControlButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            controlCircle(systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func controlCircle(systemImage: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.82))
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.78))
            }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }

        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

private final class CameraSessionController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var isReady = false
    @Published var errorMessage: String?
    @Published var isFlashAvailable = false

    private let sessionQueue = DispatchQueue(label: "driplog.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var hasConfiguredSession = false
    private var captureHandler: ((UIImage) -> Void)?

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await configureAndStartSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                await MainActor.run {
                    errorMessage = "Camera access is disabled. Allow camera access in Settings."
                }
                return
            }
            await configureAndStartSession()
        default:
            await MainActor.run {
                errorMessage = "Camera access is disabled. Allow camera access in Settings."
            }
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(flashMode: AVCaptureDevice.FlashMode, onCapture: @escaping (UIImage) -> Void) {
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        captureHandler = onCapture
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func configureAndStartSession() async {
        sessionQueue.async {
            if !self.hasConfiguredSession {
                self.configureSession()
            }

            guard self.hasConfiguredSession else { return }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.errorMessage = nil
                self.isReady = true
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        defer {
            session.commitConfiguration()
        }

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            DispatchQueue.main.async {
                self.errorMessage = "Could not start the camera."
                self.isReady = false
            }
            return
        }

        session.addInput(input)
        DispatchQueue.main.async {
            self.isFlashAvailable = camera.hasFlash
        }

        guard session.canAddOutput(photoOutput) else {
            DispatchQueue.main.async {
                self.errorMessage = "Could not capture photos on this device."
                self.isReady = false
            }
            return
        }

        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true
        hasConfiguredSession = true
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else { return }
        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data),
            let captureHandler
        else {
            return
        }

        DispatchQueue.main.async {
            captureHandler(image)
        }
    }
}

#Preview {
    HomeView(user: AppUser(id: UUID(), name: "Michael", email: "michael@example.com"), onLogOut: {})
}
