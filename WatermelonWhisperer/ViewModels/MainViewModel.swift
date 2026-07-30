//
//  MainViewModel.swift
//  WatermelonWhisperer
//

import Combine
import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    private let predictorLoader: PredictorLoader
    private let appState: AppState

    init(appState: AppState, predictorLoader: PredictorLoader) {
        self.appState = appState
        self.predictorLoader = predictorLoader
    }

    func calculateSweetness() {
        guard appState.canCalculateSweetness,
              let imageTensor = appState.capturedImageTensor,
              let audioTensor = appState.audioSpectrogramTensor else {
            return
        }

        guard let predictor = predictorLoader.predictor else {
            appState.presentError(predictorLoader.loadError ?? PipelineError.modelFileNotFound)
            return
        }

        Task {
            appState.isCalculating = true
            defer { appState.isCalculating = false }
            do {
                let value = try await predictor.predict(imageTensor: imageTensor, audioTensor: audioTensor)
                appState.sweetnessIndex = value
                HapticFeedback.success()
            } catch {
                HapticFeedback.error()
                appState.presentError(error)
            }
        }
    }
}
