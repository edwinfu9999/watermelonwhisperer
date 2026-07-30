//
//  AppState.swift
//  WatermelonWhisperer
//

import Combine
import Foundation

/// Central app state shared between the main screen and the capture flows.
/// Mutated only on the main actor; pipelines hand back finished tensors here.
@MainActor
final class AppState: ObservableObject {
    /// Flattened [1, 224, 224, 3] Float32, raw 0-255 RGB, row-major.
    @Published var capturedImageTensor: [Float]?
    /// Flattened [1, 249, 129] Float32 linear magnitude spectrogram.
    @Published var audioSpectrogramTensor: [Float]?

    @Published var isImageValid: Bool = false
    @Published var isAudioValid: Bool = false

    @Published var isCalculating: Bool = false
    @Published var sweetnessIndex: Float?

    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false

    var canCalculateSweetness: Bool {
        isImageValid && isAudioValid && !isCalculating
    }

    func setImage(tensor: [Float]) {
        capturedImageTensor = tensor
        isImageValid = true
        sweetnessIndex = nil
    }

    func setAudio(tensor: [Float]) {
        audioSpectrogramTensor = tensor
        isAudioValid = true
        sweetnessIndex = nil
    }

    func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
    }

    func reset() {
        capturedImageTensor = nil
        audioSpectrogramTensor = nil
        isImageValid = false
        isAudioValid = false
        sweetnessIndex = nil
    }
}
