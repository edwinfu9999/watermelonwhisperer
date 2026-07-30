//
//  PipelineError.swift
//  WatermelonWhisperer
//

import Foundation

/// Errors surfaced by the camera, audio, DSP, and inference pipelines.
/// Every case maps to a user-readable message; pipelines never crash on bad input.
enum PipelineError: LocalizedError {
    // Camera
    case cameraUnavailable
    case cameraConfigurationFailed
    case photoCaptureFailed(underlying: Error?)

    // Image pipeline
    case orientationFixFailed
    case noSalientObjectFound
    case objectTouchesEdge
    case objectTooSmall
    case saliencyConfidenceTooLow
    case imageCropFailed
    case imageResizeFailed

    // Audio pipeline
    case audioSessionConfigurationFailed(underlying: Error)
    case audioEngineStartFailed(underlying: Error)
    case audioConversionFailed
    case audioTooQuiet(snrDB: Float)
    case wrongNumberOfOnsets(found: Int)
    case onsetsNotEvenlySpaced
    case onsetsStartedTooSoon
    case recordingInterrupted

    // Inference
    case modelFileNotFound
    case interpreterInitializationFailed(underlying: Error)
    case unexpectedTensorShape(name: String, expected: String, actual: String)
    case tensorMatchingFailed
    case inferenceFailed(underlying: Error)

    // Permissions
    case cameraPermissionDenied
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "No camera is available on this device."
        case .cameraConfigurationFailed:
            return "Could not start the camera. Please try again."
        case .photoCaptureFailed:
            return "Could not capture the photo. Please try again."
        case .orientationFixFailed:
            return "Could not process the photo. Please try again."
        case .noSalientObjectFound:
            return "Please retake the photo. Make sure the entire watermelon is in frame and the background is as clean as possible."
        case .objectTouchesEdge:
            return "Please retake the photo. Make sure the whole watermelon fits inside the frame."
        case .objectTooSmall:
            return "Please retake the photo. Move closer so the watermelon fills more of the frame."
        case .saliencyConfidenceTooLow:
            return "Please retake the photo. Make sure the entire watermelon is in frame and the background is as clean as possible."
        case .imageCropFailed, .imageResizeFailed:
            return "Could not process the photo. Please try again."
        case .audioSessionConfigurationFailed:
            return "Could not access the microphone. Please try again."
        case .audioEngineStartFailed:
            return "Could not start recording. Please try again."
        case .audioConversionFailed:
            return "Could not process the recording. Please try again."
        case .audioTooQuiet:
            return "Too noisy! Please move to a quieter area."
        case .wrongNumberOfOnsets, .onsetsNotEvenlySpaced, .onsetsStartedTooSoon:
            return "Please re-record. Make sure the three thumps happen about 0.5 seconds apart, background noise is low, and tapping starts about 1 second after the recording begins."
        case .recordingInterrupted:
            return "Recording was interrupted. Please try again."
        case .modelFileNotFound:
            return "The sweetness model could not be found. Please reinstall the app."
        case .interpreterInitializationFailed:
            return "The sweetness model could not be loaded. Please reinstall the app."
        case .unexpectedTensorShape(let name, let expected, let actual):
            return "The sweetness model's \(name) tensor has an unexpected shape (expected \(expected), got \(actual)). Please reinstall the app."
        case .tensorMatchingFailed:
            return "The sweetness model's inputs could not be identified. Please reinstall the app."
        case .inferenceFailed:
            return "Could not calculate sweetness. Please try again."
        case .cameraPermissionDenied:
            return "Camera access is required to take a photo of the watermelon. Please enable it in Settings."
        case .microphonePermissionDenied:
            return "Microphone access is required to record the taps. Please enable it in Settings."
        }
    }
}
