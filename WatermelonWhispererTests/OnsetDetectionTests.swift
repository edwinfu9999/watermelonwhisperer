//
//  OnsetDetectionTests.swift
//  WatermelonWhispererTests
//

import XCTest
@testable import WatermelonWhisperer

final class OnsetDetectionTests: XCTestCase {
    func testDetectsThreeEvenlySpacedSyntheticTaps() {
        let sampleRate = 16_000
        let sampleCount = sampleRate * 3 // 3 seconds
        var signal = [Float](repeating: 0, count: sampleCount)

        for i in 0..<sampleCount {
            signal[i] = Float.random(in: -0.005...0.005)
        }

        // Taps at 0.5s, 1.0s, 1.5s: 0.5s apart, first onset 0.5s after start.
        let tapStarts = [8_000, 16_000, 24_000]
        for start in tapStarts {
            addSyntheticTap(into: &signal, at: start, sampleRate: sampleRate)
        }

        let noiseRMS = SignalMath.noiseFloorRMS(signal: signal)
        let onsets = OnsetDetector.detectOnsets(signal: signal, noiseRMS: noiseRMS)

        XCTAssertEqual(onsets.count, 3)
        for (index, expectedStart) in tapStarts.enumerated() {
            guard index < onsets.count else { continue }
            // Within 25ms (400 samples) of the true tap start.
            XCTAssertEqual(Float(onsets[index]), Float(expectedStart), accuracy: 400)
        }
    }

    func testRejectsRecordingWithWrongOnsetCount() {
        let sampleRate = 16_000
        var signal = [Float](repeating: 0, count: sampleRate * 3)
        for i in 0..<signal.count {
            signal[i] = Float.random(in: -0.005...0.005)
        }
        addSyntheticTap(into: &signal, at: 8_000, sampleRate: sampleRate)
        addSyntheticTap(into: &signal, at: 16_000, sampleRate: sampleRate)
        // Only two taps.

        let pipeline = AudioPipeline()
        XCTAssertThrowsError(try pipeline.processRecording(signal)) { error in
            guard let pipelineError = error as? PipelineError else {
                XCTFail("expected PipelineError, got \(error)")
                return
            }
            guard case .wrongNumberOfOnsets = pipelineError else {
                XCTFail("expected wrongNumberOfOnsets, got \(pipelineError)")
                return
            }
        }
    }

    private func addSyntheticTap(
        into signal: inout [Float],
        at start: Int,
        sampleRate: Int,
        amplitude: Float = 0.8,
        decay: Float = 0.01
    ) {
        let length = Int(0.05 * Float(sampleRate))
        for i in 0..<length {
            let index = start + i
            guard index < signal.count else { break }
            let t = Float(i) / Float(sampleRate)
            let envelope = amplitude * exp(-t / decay)
            signal[index] += envelope * sin(2 * Float.pi * 900 * t)
        }
    }
}
