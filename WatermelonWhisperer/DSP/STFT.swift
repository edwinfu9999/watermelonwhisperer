//
//  STFT.swift
//  WatermelonWhisperer
//
//  Real-valued STFT magnitude spectrogram computed to numerically match
//  tf.signal.stft(waveform, frame_length: 256, frame_step: 128, fft_length: 256)
//  with a periodic Hann window and pad_end = false.
//

import Accelerate
import Foundation

/// Computes magnitude spectrograms using vDSP's real-packed FFT.
/// Explicitly non-isolated: pure CPU computation that must run off the main actor.
nonisolated final class STFT {
    static let frameLength = 256
    static let frameStep = 128
    static let fftLength = 256
    /// fft_length / 2 + 1
    static let numBins = fftLength / 2 + 1

    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let window: [Float]

    init() {
        log2n = vDSP_Length(log2(Double(Self.fftLength)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to create FFT setup — this indicates a fixed, non-recoverable configuration error.")
        }
        fftSetup = setup
        window = STFT.periodicHannWindow(length: Self.frameLength)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// TensorFlow's default Hann window is periodic: 0.5 - 0.5*cos(2*pi*n/N), divisor N (not N-1).
    static func periodicHannWindow(length: Int) -> [Float] {
        (0..<length).map { n in
            0.5 - 0.5 * cos(2.0 * Float.pi * Float(n) / Float(length))
        }
    }

    /// - Parameter signal: exactly 32,000 samples (2 s @ 16 kHz).
    /// - Returns: magnitude spectrogram, shape [numFrames][numBins], numFrames == 249.
    func magnitudeSpectrogram(signal: [Float]) -> [[Float]] {
        precondition(signal.count >= Self.frameLength, "signal shorter than one STFT frame")

        let numFrames = 1 + (signal.count - Self.frameLength) / Self.frameStep
        var output = [[Float]](repeating: [Float](repeating: 0, count: Self.numBins), count: numFrames)

        var realp = [Float](repeating: 0, count: Self.fftLength / 2)
        var imagp = [Float](repeating: 0, count: Self.fftLength / 2)
        var windowedFrame = [Float](repeating: 0, count: Self.frameLength)

        for frameIndex in 0..<numFrames {
            let start = frameIndex * Self.frameStep
            signal.withUnsafeBufferPointer { signalPtr in
                windowedFrame.withUnsafeMutableBufferPointer { framePtr in
                    vDSP_vmul(signalPtr.baseAddress! + start, 1, window, 1, framePtr.baseAddress!, 1, vDSP_Length(Self.frameLength))
                }
            }

            realp.withUnsafeMutableBufferPointer { realPtr in
                imagp.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    windowedFrame.withUnsafeBufferPointer { framePtr in
                        framePtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Self.fftLength / 2) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(Self.fftLength / 2))
                        }
                    }
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                }
            }

            // vDSP's packed real FFT returns values scaled 2x true DFT coefficients.
            // DC and Nyquist are real-only and packed into realp[0]/imagp[0] respectively.
            var bins = [Float](repeating: 0, count: Self.numBins)
            bins[0] = abs(realp[0] / 2.0)
            bins[Self.numBins - 1] = abs(imagp[0] / 2.0)
            for k in 1..<(Self.fftLength / 2) {
                let re = realp[k] / 2.0
                let im = imagp[k] / 2.0
                bins[k] = sqrt(re * re + im * im)
            }
            output[frameIndex] = bins
        }

        return output
    }

    /// Flattens [numFrames][numBins] into row-major [1, numFrames, numBins].
    static func flatten(_ spectrogram: [[Float]]) -> [Float] {
        var flat = [Float]()
        flat.reserveCapacity(spectrogram.count * numBins)
        for frame in spectrogram {
            flat.append(contentsOf: frame)
        }
        return flat
    }
}
