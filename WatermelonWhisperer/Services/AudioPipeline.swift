//
//  AudioPipeline.swift
//  WatermelonWhisperer
//
//  SNR guardrail, onset validation, 2-second crop, and STFT tensor prep.
//  Runs synchronously; callers are responsible for dispatching off the main thread.
//

import Foundation

protocol AudioPipelineProtocol {
    /// `signal` must be 16 kHz mono Float32. Returns a flattened [1, 249, 129] magnitude spectrogram.
    nonisolated func processRecording(_ signal: [Float]) throws -> [Float]
}

/// Explicitly non-isolated: this does CPU-heavy DSP work that must run on a background thread
/// via Task.detached, not implicitly hop to the main actor (the project's default actor
/// isolation is MainActor).
nonisolated final class AudioPipeline: AudioPipelineProtocol {
    enum Config {
        static let minimumSNRdB: Float = 12
        /// 0.25 s lead-in before the first onset, per the corrected 2-second training window.
        static let leadInSamples = 4_000
        /// 2 s @ 16 kHz, matching the training clip length.
        static let windowSamples = 32_000
        static let minOnsetGapSamples = 4_800   // 0.3 s
        static let maxOnsetGapSamples = 12_800  // 0.8 s
        static let minFirstOnsetSamples = 8_000 // 0.5 s
        static let expectedOnsetCount = 3
    }

    private let stft: STFT

    init(stft: STFT = STFT()) {
        self.stft = stft
    }

    func processRecording(_ signal: [Float]) throws -> [Float] {
        let noiseRMS = SignalMath.noiseFloorRMS(signal: signal)
        let peak = SignalMath.peakAmplitude(signal: signal, from: 1_600)
        let snr = SignalMath.snrDB(peak: peak, noiseRMS: noiseRMS)
        guard snr >= Config.minimumSNRdB else {
            throw PipelineError.audioTooQuiet(snrDB: snr)
        }

        let onsets = OnsetDetector.detectOnsets(signal: signal, noiseRMS: noiseRMS)
        try validate(onsets: onsets)

        let cropped = crop(signal: signal, firstOnset: onsets[0])
        let spectrogram = stft.magnitudeSpectrogram(signal: cropped)
        return STFT.flatten(spectrogram)
    }

    private func validate(onsets: [Int]) throws {
        guard onsets.count == Config.expectedOnsetCount else {
            throw PipelineError.wrongNumberOfOnsets(found: onsets.count)
        }
        guard onsets[0] >= Config.minFirstOnsetSamples else {
            throw PipelineError.onsetsStartedTooSoon
        }
        for i in 1..<onsets.count {
            let gap = onsets[i] - onsets[i - 1]
            guard gap >= Config.minOnsetGapSamples, gap <= Config.maxOnsetGapSamples else {
                throw PipelineError.onsetsNotEvenlySpaced
            }
        }
    }

    /// Extracts a strict `windowSamples`-length window starting `leadInSamples` before
    /// the first onset. Clamped to 0 at the start; zero-padded at the end.
    private func crop(signal: [Float], firstOnset: Int) -> [Float] {
        let start = max(0, firstOnset - Config.leadInSamples)
        var window = [Float](repeating: 0, count: Config.windowSamples)
        let available = signal.count - start
        let copyCount = min(Config.windowSamples, max(0, available))
        if copyCount > 0 {
            window.replaceSubrange(0..<copyCount, with: signal[start..<(start + copyCount)])
        }
        return window
    }
}
