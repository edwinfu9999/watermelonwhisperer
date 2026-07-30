//
//  PermissionsService.swift
//  WatermelonWhisperer
//

import AVFoundation
import Foundation

/// Requests and reports camera/microphone permission state.
protocol PermissionsServiceProtocol {
    func requestCameraAccess() async -> Bool
    func requestMicrophoneAccess() async -> Bool
}

final class PermissionsService: PermissionsServiceProtocol {
    func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func requestMicrophoneAccess() async -> Bool {
        // AVAudioApplication's permission API is iOS 17+; AVAudioSession's is the iOS 16-compatible route.
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return true
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
