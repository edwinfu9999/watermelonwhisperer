//
//  STFTTests.swift
//  WatermelonWhispererTests
//

import XCTest
@testable import WatermelonWhisperer

final class STFTTests: XCTestCase {
    /// Verifies STFT.swift's vDSP-based real-FFT implementation (including the /2 scaling
    /// convention for vDSP_fft_zrip's packed output) against an independently computed,
    /// brute-force DFT over the exact same windowed frame.
    func testSTFTMatchesDirectDFTFor440HzSine() {
        let sampleRate: Float = 16_000
        let frequency: Float = 440
        let sampleCount = 32_000

        var signal = [Float](repeating: 0, count: sampleCount)
        for n in 0..<sampleCount {
            signal[n] = sin(2 * Float.pi * frequency * Float(n) / sampleRate)
        }

        let stft = STFT()
        let spectrogram = stft.magnitudeSpectrogram(signal: signal)

        XCTAssertEqual(spectrogram.count, 249)
        XCTAssertEqual(spectrogram.first?.count, 129)

        let frameIndex = 100
        let start = frameIndex * STFT.frameStep
        let window = STFT.periodicHannWindow(length: STFT.frameLength)
        var windowedFrame = [Float](repeating: 0, count: STFT.frameLength)
        for i in 0..<STFT.frameLength {
            windowedFrame[i] = signal[start + i] * window[i]
        }

        let expectedBin = Int((frequency * Float(STFT.fftLength) / sampleRate).rounded())

        // Ground-truth direct DFT (O(N^2), fine for a single test frame).
        var groundTruth = [Float](repeating: 0, count: STFT.numBins)
        for k in 0..<STFT.numBins {
            var re: Float = 0
            var im: Float = 0
            for n in 0..<STFT.frameLength {
                let angle = -2 * Float.pi * Float(k) * Float(n) / Float(STFT.fftLength)
                re += windowedFrame[n] * cos(angle)
                im += windowedFrame[n] * sin(angle)
            }
            groundTruth[k] = sqrt(re * re + im * im)
        }
        let groundTruthPeakBin = groundTruth.indices.max(by: { groundTruth[$0] < groundTruth[$1] })!
        XCTAssertEqual(groundTruthPeakBin, expectedBin, "sanity check on the test's own ground truth")

        let stftFrame = spectrogram[frameIndex]
        let stftPeakBin = stftFrame.indices.max(by: { stftFrame[$0] < stftFrame[$1] })!

        XCTAssertEqual(stftPeakBin, expectedBin, "STFT peak bin should match the 440 Hz sine's expected bin")
        XCTAssertEqual(
            stftFrame[expectedBin],
            groundTruth[expectedBin],
            accuracy: max(groundTruth[expectedBin] * 0.01, 0.01),
            "STFT magnitude at the peak bin should match the direct-DFT ground truth within 1%"
        )
    }
}
