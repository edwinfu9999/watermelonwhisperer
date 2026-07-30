//
//  CameraService.swift
//  WatermelonWhisperer
//
//  Thin AVFoundation wrapper: owns the capture session and preview layer,
//  and turns a shutter press into an async UIImage. All session work runs
//  on a dedicated serial queue, never the main thread.
//

@preconcurrency import AVFoundation
import UIKit

protocol CameraServiceProtocol: AnyObject {
    var previewLayer: AVCaptureVideoPreviewLayer { get }
    func configureSession() throws
    func startSession()
    func stopSession()
    func capturePhoto() async throws -> UIImage
}

final class CameraService: NSObject, CameraServiceProtocol {
    let previewLayer: AVCaptureVideoPreviewLayer

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.watermelonwhisperer.camera.session")
    // Touched only from within `sessionQueue`-confined closures (including the nonisolated
    // AVCapturePhotoCaptureDelegate callback below), which serializes access manually;
    // the compiler can't see that guarantee through the actor-isolation checker.
    private nonisolated(unsafe) var photoContinuation: CheckedContinuation<UIImage, Error>?

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
    }

    func configureSession() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw PipelineError.cameraUnavailable
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            throw PipelineError.cameraConfigurationFailed
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            throw PipelineError.cameraConfigurationFailed
        }
        photoOutput.maxPhotoQualityPrioritization = .quality
        session.addOutput(photoOutput)
    }

    func startSession() {
        sessionQueue.async { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.photoContinuation = continuation
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .auto
                settings.photoQualityPrioritization = .quality
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    // AVFoundation invokes this on the queue `capturePhoto` was called from (sessionQueue),
    // not the main actor — must be nonisolated to satisfy the (nonisolated) delegate requirement.
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let continuation = photoContinuation
        photoContinuation = nil

        if let error {
            continuation?.resume(throwing: PipelineError.photoCaptureFailed(underlying: error))
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            continuation?.resume(throwing: PipelineError.photoCaptureFailed(underlying: nil))
            return
        }
        continuation?.resume(returning: image)
    }
}
