//
//  SweetnessPredictor.swift
//  WatermelonWhisperer
//
//  Loads watermelonClass.tflite once, matches its inputs by rank/shape/name
//  rather than assuming index order, and reuses a single Interpreter for
//  every prediction. All interpreter calls happen on a dedicated queue.
//

import Foundation
import TensorFlowLite

protocol SweetnessPredictorProtocol {
    func predict(imageTensor: [Float], audioTensor: [Float]) async throws -> Float
}

/// Explicitly non-isolated: loading the model and invoking the interpreter must run off the
/// main actor (the project's default actor isolation is MainActor), and this type is already
/// internally thread-safe via its own dedicated serial queue.
nonisolated final class SweetnessPredictor: SweetnessPredictorProtocol {
    static let imageTensorElementCount = 1 * 224 * 224 * 3
    static let audioFrameCount = 249
    static let audioBinCount = 129

    private let interpreter: Interpreter
    private let imageInputIndex: Int
    private let audioInputIndex: Int
    private let queue = DispatchQueue(label: "com.watermelonwhisperer.tflite", qos: .userInitiated)

    init(modelFileName: String = "watermelonClass", modelFileExtension: String = "tflite") throws {
        guard let modelPath = Bundle.main.path(forResource: modelFileName, ofType: modelFileExtension) else {
            throw PipelineError.modelFileNotFound
        }

        // The model contains a non-fused (Bidirectional) LSTM, which the converter lowers to
        // TensorList/TensorArray ops wrapped as Flex custom ops. Those need the Flex delegate
        // from TensorFlowLiteSelectTfOps. The TFLite runtime attaches it automatically at
        // interpreter creation by dlsym-ing "TF_AcquireFlexDelegate" — but only if that symbol
        // survives linking, which requires the app target's OTHER_LDFLAGS to -force_load the
        // (static, pure-C++) TensorFlowLiteSelectTfOps framework binary. See the project's
        // build settings; without that flag this init fails with "Select TensorFlow op(s)
        // ... not supported".
        let loadedInterpreter: Interpreter
        do {
            loadedInterpreter = try Interpreter(modelPath: modelPath)
            try loadedInterpreter.allocateTensors()
        } catch {
            throw PipelineError.interpreterInitializationFailed(underlying: error)
        }

        print("SweetnessPredictor: loaded \(modelFileName).\(modelFileExtension) — \(loadedInterpreter.inputTensorCount) input(s), \(loadedInterpreter.outputTensorCount) output(s)")

        var imageIndex: Int?
        var audioIndex: Int?
        for i in 0..<loadedInterpreter.inputTensorCount {
            guard let tensor = try? loadedInterpreter.input(at: i) else { continue }
            let dims = tensor.shape.dimensions
            print("  input[\(i)] name=\"\(tensor.name)\" shape=\(dims) dtype=\(tensor.dataType)")

            let lowerName = tensor.name.lowercased()
            if lowerName.contains("image") {
                imageIndex = i
            } else if lowerName.contains("audio") {
                audioIndex = i
            } else if dims.count == 4 {
                imageIndex = imageIndex ?? i
            } else if dims.count == 3 {
                audioIndex = audioIndex ?? i
            }
        }
        for o in 0..<loadedInterpreter.outputTensorCount {
            guard let tensor = try? loadedInterpreter.output(at: o) else { continue }
            print("  output[\(o)] name=\"\(tensor.name)\" shape=\(tensor.shape.dimensions) dtype=\(tensor.dataType)")
        }

        guard let resolvedImageIndex = imageIndex,
              let resolvedAudioIndex = audioIndex,
              resolvedImageIndex != resolvedAudioIndex else {
            throw PipelineError.tensorMatchingFailed
        }

        // The Keras audio input was declared (None, 129); resize the dynamic time
        // dimension to 249 before allocating, if the converter left it dynamic or wrong.
        if let audioTensor = try? loadedInterpreter.input(at: resolvedAudioIndex) {
            let dims = audioTensor.shape.dimensions
            let needsResize = dims.count == 3 && dims[1] != Self.audioFrameCount
            if needsResize {
                do {
                    try loadedInterpreter.resizeInput(
                        at: resolvedAudioIndex,
                        to: Tensor.Shape([1, Self.audioFrameCount, Self.audioBinCount])
                    )
                    try loadedInterpreter.allocateTensors()
                } catch {
                    throw PipelineError.interpreterInitializationFailed(underlying: error)
                }
            }
        }

        interpreter = loadedInterpreter
        imageInputIndex = resolvedImageIndex
        audioInputIndex = resolvedAudioIndex
    }

    func predict(imageTensor: [Float], audioTensor: [Float]) async throws -> Float {
        guard imageTensor.count == Self.imageTensorElementCount else {
            throw PipelineError.unexpectedTensorShape(
                name: "image_input",
                expected: "\(Self.imageTensorElementCount) elements",
                actual: "\(imageTensor.count) elements"
            )
        }
        guard audioTensor.count == Self.audioFrameCount * Self.audioBinCount else {
            throw PipelineError.unexpectedTensorShape(
                name: "audio_input",
                expected: "\(Self.audioFrameCount * Self.audioBinCount) elements",
                actual: "\(audioTensor.count) elements"
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return }
                do {
                    try self.interpreter.copy(Data(copyingBufferOf: imageTensor), toInputAt: self.imageInputIndex)
                    try self.interpreter.copy(Data(copyingBufferOf: audioTensor), toInputAt: self.audioInputIndex)
                    try self.interpreter.invoke()
                    let outputTensor = try self.interpreter.output(at: 0)
                    guard let values = [Float](unsafeData: outputTensor.data), let first = values.first else {
                        throw PipelineError.inferenceFailed(underlying: NSError(
                            domain: "WatermelonWhisperer",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "Output tensor could not be decoded."]
                        ))
                    }
                    continuation.resume(returning: first)
                } catch let error as PipelineError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: PipelineError.inferenceFailed(underlying: error))
                }
            }
        }
    }
}

private extension Data {
    init<T>(copyingBufferOf array: [T]) {
        self = array.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

private extension Array {
    init?(unsafeData: Data) {
        guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
        self = unsafeData.withUnsafeBytes { Array($0.bindMemory(to: Element.self)) }
    }
}
