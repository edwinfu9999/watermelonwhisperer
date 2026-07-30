//
//  AudioRecorderService.swift
//  WatermelonWhisperer
//
//  Records a fixed-duration clip from the hardware input and resamples it
//  to 16 kHz mono Float32 via AVAudioConverter. All buffer accumulation is
//  confined to a serial queue; the tap callback itself only converts.
//

@preconcurrency import AVFoundation
import Foundation

protocol AudioRecorderServiceProtocol: AnyObject {
    /// Records for `duration` seconds and returns exactly `duration * 16_000` mono Float32 samples.
    func record(duration: TimeInterval) async throws -> [Float]
    func cancel()
}

final class AudioRecorderService: NSObject, AudioRecorderServiceProtocol {
    static let targetSampleRate: Double = 16_000

    private let engine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "com.watermelonwhisperer.audio.processing")

    private var collectedSamples: [Float] = []
    private var targetSampleCount: Int = 0
    private var continuation: CheckedContinuation<[Float], Error>?
    private var isRecording = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func record(duration: TimeInterval) async throws -> [Float] {
        try configureSession()

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw PipelineError.audioConversionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self else { return }
                self.collectedSamples = []
                self.targetSampleCount = Int(duration * Self.targetSampleRate)
                self.continuation = continuation
                self.isRecording = true

                inputNode.installTap(onBus: 0, bufferSize: 4_096, format: hardwareFormat) { [weak self] buffer, _ in
                    self?.handle(buffer: buffer, converter: converter, targetFormat: targetFormat)
                }

                do {
                    self.engine.prepare()
                    try self.engine.start()
                } catch {
                    self.isRecording = false
                    inputNode.removeTap(onBus: 0)
                    self.continuation = nil
                    continuation.resume(throwing: PipelineError.audioEngineStartFailed(underlying: error))
                }
            }
        }
    }

    func cancel() {
        processingQueue.async { [weak self] in
            self?.finish(with: .failure(PipelineError.recordingInterrupted))
        }
    }

    // MARK: - Private

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw PipelineError.audioSessionConfigurationFailed(underlying: error)
        }
    }

    /// Runs on the AVAudioEngine tap thread. Only performs the (stateless per-call) conversion;
    /// all shared mutable state is touched exclusively on `processingQueue`.
    private func handle(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        let ratio = targetFormat.sampleRate / converter.inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            return
        }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, let channelData = outputBuffer.floatChannelData else { return }
        let frameCount = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        processingQueue.async { [weak self] in
            guard let self, self.isRecording else { return }
            self.collectedSamples.append(contentsOf: samples)
            if self.collectedSamples.count >= self.targetSampleCount {
                self.finish(with: .success(Array(self.collectedSamples.prefix(self.targetSampleCount))))
            }
        }
    }

    /// Must be called on `processingQueue`.
    private func finish(with result: Result<[Float], Error>) {
        guard isRecording else { return }
        isRecording = false

        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let continuation = self.continuation
        self.continuation = nil
        switch result {
        case .success(let samples):
            continuation?.resume(returning: samples)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              type == .began else {
            return
        }
        cancel()
    }
}
