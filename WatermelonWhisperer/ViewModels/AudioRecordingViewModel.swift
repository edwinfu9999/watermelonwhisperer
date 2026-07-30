//
//  AudioRecordingViewModel.swift
//  WatermelonWhisperer
//

import Combine
import Foundation

@MainActor
final class AudioRecordingViewModel: ObservableObject {
    static let recordingDuration: TimeInterval = 5.0

    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var alert: CaptureAlert?

    private let recorderService: AudioRecorderServiceProtocol
    private let audioPipeline: AudioPipelineProtocol
    private let permissionsService: PermissionsServiceProtocol
    private let appState: AppState

    init(
        appState: AppState,
        recorderService: AudioRecorderServiceProtocol? = nil,
        audioPipeline: AudioPipelineProtocol = AudioPipeline(),
        permissionsService: PermissionsServiceProtocol? = nil
    ) {
        // AudioRecorderService/PermissionsService are constructed here (inside this @MainActor
        // init body) rather than as default parameter expressions, since default-argument
        // expressions are evaluated in the *caller's* isolation context, which may not be
        // the main actor.
        self.appState = appState
        self.recorderService = recorderService ?? AudioRecorderService()
        self.audioPipeline = audioPipeline
        self.permissionsService = permissionsService ?? PermissionsService()
    }

    func startRecording() {
        guard !isRecording, !isProcessing else { return }

        Task {
            let granted = await permissionsService.requestMicrophoneAccess()
            guard granted else {
                alert = .permissionDenied(PipelineError.microphonePermissionDenied.localizedDescription)
                return
            }

            isRecording = true
            do {
                let signal = try await recorderService.record(duration: Self.recordingDuration)
                isRecording = false
                isProcessing = true

                let pipeline = audioPipeline
                let tensor = try await Task.detached(priority: .userInitiated) {
                    try pipeline.processRecording(signal)
                }.value

                isProcessing = false
                appState.setAudio(tensor: tensor)
                HapticFeedback.success()
                alert = .success("Recording accepted ✓")
            } catch {
                isRecording = false
                isProcessing = false
                HapticFeedback.error()
                alert = .failure(error.localizedDescription)
            }
        }
    }

    func cancelRecording() {
        guard isRecording else { return }
        recorderService.cancel()
        isRecording = false
    }
}
