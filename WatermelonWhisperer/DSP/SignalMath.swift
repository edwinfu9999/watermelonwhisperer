//
//  SignalMath.swift
//  WatermelonWhisperer
//
//  SNR estimation and tap-onset detection over a 16 kHz mono Float32 buffer.
//

import Accelerate
import Foundation

/// Explicitly non-isolated: pure CPU computation that must run off the main actor.
nonisolated enum SignalMath {
    static let sampleRate = 16_000

    // MARK: - SNR

    /// RMS of the first 100 ms (1,600 samples), used as the noise floor estimate.
    static func noiseFloorRMS(signal: [Float]) -> Float {
        let count = min(1_600, signal.count)
        guard count > 0 else { return 0 }
        var value: Float = 0
        signal.withUnsafeBufferPointer { buf in
            vDSP_rmsqv(buf.baseAddress!, 1, &value, vDSP_Length(count))
        }
        return value
    }

    /// Maximum absolute amplitude from `start` to the end of the buffer.
    static func peakAmplitude(signal: [Float], from start: Int) -> Float {
        guard start < signal.count else { return 0 }
        var value: Float = 0
        signal.withUnsafeBufferPointer { buf in
            vDSP_maxmgv(buf.baseAddress! + start, 1, &value, vDSP_Length(signal.count - start))
        }
        return value
    }

    static func snrDB(peak: Float, noiseRMS: Float) -> Float {
        20 * log10(peak / max(noiseRMS, 1e-9))
    }
}

/// Detects tap onsets via a short-window RMS envelope with a rise threshold and refractory period.
/// Explicitly non-isolated: pure CPU computation that must run off the main actor.
nonisolated enum OnsetDetector {
    /// 20 ms window @ 16 kHz
    static let windowSamples = 320
    /// 10 ms hop @ 16 kHz
    static let hopSamples = 160
    /// 150 ms refractory period between accepted onsets
    static let refractorySamples = 2_400
    /// Onset threshold = noiseRMS * thresholdMultiplier
    static let thresholdMultiplier: Float = 6.0
    /// A window must be at least this much louder than the previous window to count as a "rise"
    static let riseMultiplier: Float = 2.0

    /// Short-window RMS envelope, one value per hop.
    static func energyEnvelope(signal: [Float]) -> [Float] {
        var envelope = [Float]()
        var index = 0
        while index + windowSamples <= signal.count {
            var value: Float = 0
            signal.withUnsafeBufferPointer { buf in
                vDSP_rmsqv(buf.baseAddress! + index, 1, &value, vDSP_Length(windowSamples))
            }
            envelope.append(value)
            index += hopSamples
        }
        return envelope
    }

    /// Returns the sample index (start of the detected window) of every distinct onset,
    /// enforcing a refractory period between consecutive onsets.
    static func detectOnsets(signal: [Float], noiseRMS: Float) -> [Int] {
        let envelope = energyEnvelope(signal: signal)
        guard envelope.count > 1 else { return [] }

        let threshold = noiseRMS * thresholdMultiplier
        var onsets: [Int] = []

        for w in 1..<envelope.count {
            let value = envelope[w]
            let previous = envelope[w - 1]
            guard value > threshold, value >= riseMultiplier * previous else { continue }

            let sampleIndex = w * hopSamples
            if let last = onsets.last, sampleIndex - last < refractorySamples {
                continue
            }
            onsets.append(sampleIndex)
        }

        return onsets
    }
}
