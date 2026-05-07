
import AVFoundation
import Combine
import UIKit

final class CameraSessionController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var isReady = false
    @Published var errorMessage: String?
    @Published var isFlashAvailable = false

    private let sessionQueue = DispatchQueue(label: "driplog.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var hasConfiguredSession = false
    private var captureHandler: ((UIImage) -> Void)?

    // MARK: - Lifecycle

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

    // MARK: - Session Configuration

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

        defer { session.commitConfiguration() }

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

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else { return }
        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data),
            let captureHandler
        else { return }

        DispatchQueue.main.async {
            captureHandler(image)
        }
    }
}