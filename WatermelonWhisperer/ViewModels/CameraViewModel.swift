//
//  CameraViewModel.swift
//  WatermelonWhisperer
//

import Combine
import Foundation
import UIKit

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var alert: CaptureAlert?

    let cameraService: CameraServiceProtocol

    private let imagePipeline: ImagePipelineProtocol
    private let permissionsService: PermissionsServiceProtocol
    private let appState: AppState

    init(
        appState: AppState,
        cameraService: CameraServiceProtocol? = nil,
        imagePipeline: ImagePipelineProtocol = ImagePipeline(),
        permissionsService: PermissionsServiceProtocol? = nil
    ) {
        // CameraService/PermissionsService are constructed here (inside this @MainActor init
        // body) rather than as default parameter expressions, since default-argument
        // expressions are evaluated in the *caller's* isolation context, which may not be
        // the main actor.
        self.appState = appState
        self.cameraService = cameraService ?? CameraService()
        self.imagePipeline = imagePipeline
        self.permissionsService = permissionsService ?? PermissionsService()
    }

    func startSession() {
        Task {
            let granted = await permissionsService.requestCameraAccess()
            guard granted else {
                alert = .permissionDenied(PipelineError.cameraPermissionDenied.localizedDescription)
                return
            }
            do {
                try cameraService.configureSession()
                cameraService.startSession()
            } catch {
                alert = .failure(error.localizedDescription)
            }
        }
    }

    func stopSession() {
        cameraService.stopSession()
    }

    func capture() {
        guard !isProcessing else { return }
        isProcessing = true

        Task {
            defer { isProcessing = false }
            do {
                let image = try await cameraService.capturePhoto()
                let pipeline = imagePipeline
                let tensor = try await Task.detached(priority: .userInitiated) {
                    try pipeline.processImage(image)
                }.value
                appState.setImage(tensor: tensor)
                HapticFeedback.success()
                alert = .success("Photo accepted ✓")
            } catch {
                HapticFeedback.error()
                alert = .failure(error.localizedDescription)
            }
        }
    }
}
