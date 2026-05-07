import SwiftUI
import UIKit

struct CreateTab: View {
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