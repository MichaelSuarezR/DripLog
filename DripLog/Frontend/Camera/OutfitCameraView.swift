
import SwiftUI
import PhotosUI

struct OutfitCameraView: View {
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
                    circularControlButton(systemImage: "chevron.left") { dismiss() }
                    Spacer()
                    Button(action: toggleFlash) {
                        Circle()
                            .fill(Color.white.opacity(0.82))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.78))
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!cameraController.isFlashAvailable || isLoadingLibraryImage)
                    .opacity(cameraController.isFlashAvailable ? 1 : 0.45)
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
                        controlCircle(systemImage: "rectangle.on.rectangle")
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

                    Button(action: { cameraController.flipCamera() }) {
                        controlCircle(systemImage: "arrow.triangle.2.circlepath.camera")
                    }
                    .buttonStyle(.plain)
                    .disabled(!cameraController.isReady || isLoadingLibraryImage)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
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

    // MARK: - Actions

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
            else { return }
            onCapture(image)
        }
    }

    // MARK: - Control Buttons

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