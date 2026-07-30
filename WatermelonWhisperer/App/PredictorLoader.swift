//
//  PredictorLoader.swift
//  WatermelonWhisperer
//
//  Loads watermelonClass.tflite off the main thread at app start and caches
//  the single reusable Interpreter-backed predictor for the rest of the session.
//

import Combine
import Foundation

@MainActor
final class PredictorLoader: ObservableObject {
    @Published private(set) var predictor: SweetnessPredictorProtocol?
    @Published private(set) var loadError: Error?

    init() {
        Task { await load() }
    }

    private func load() async {
        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                try SweetnessPredictor()
            }.value
            predictor = loaded
        } catch {
            loadError = error
            print("SweetnessPredictor failed to load: \(error.localizedDescription)")
        }
    }
}
