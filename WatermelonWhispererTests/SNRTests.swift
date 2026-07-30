//
//  SNRTests.swift
//  WatermelonWhispererTests
//

import XCTest
@testable import WatermelonWhisperer

final class SNRTests: XCTestCase {
    func testSNRComputationForKnownSignal() {
        let sampleRate = 16_000
        var signal = [Float](repeating: 0, count: sampleRate)

        // Noise floor: first 1,600 samples alternating +/-0.01 (RMS == 0.01).
        for i in 0..<1_600 {
            signal[i] = (i % 2 == 0) ? 0.01 : -0.01
        }
        signal[8_000] = 0.5 // peak, well after the noise-floor window

        let noiseRMS = SignalMath.noiseFloorRMS(signal: signal)
        XCTAssertEqual(noiseRMS, 0.01, accuracy: 0.0001)

        let peak = SignalMath.peakAmplitude(signal: signal, from: 1_600)
        XCTAssertEqual(peak, 0.5, accuracy: 0.0001)

        let snr = SignalMath.snrDB(peak: peak, noiseRMS: noiseRMS)
        let expected = 20 * log10(Float(0.5) / Float(0.01))
        XCTAssertEqual(snr, expected, accuracy: 0.01)
    }

    func testAudioPipelineRejectsLowSNRRecording() {
        let sampleRate = 16_000
        var signal = [Float](repeating: 0, count: sampleRate * 2)
        for i in 0..<signal.count {
            // Uniform low-level noise throughout: no tap ever rises meaningfully above the
            // noise floor, so SNR should land well under the 12 dB guardrail.
            signal[i] = Float.random(in: -0.01...0.01)
        }

        let pipeline = AudioPipeline()
        XCTAssertThrowsError(try pipeline.processRecording(signal)) { error in
            guard let pipelineError = error as? PipelineError else {
                XCTFail("expected PipelineError, got \(error)")
                return
            }
            guard case .audioTooQuiet = pipelineError else {
                XCTFail("expected audioTooQuiet, got \(pipelineError)")
                return
            }
        }
    }
}
