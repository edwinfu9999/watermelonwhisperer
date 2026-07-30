//
//  AudioRecordingView.swift
//  WatermelonWhisperer
//

import SwiftUI

struct AudioRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AudioRecordingViewModel

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: AudioRecordingViewModel(appState: appState))
    }

    var body: some View {
        VStack(spacing: 36) {
            HStack {
                Button {
                    viewModel.cancelRecording()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .padding()
                Spacer()
            }

            Spacer()

            Text(statusText)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .animation(.default, value: statusText)

            PulsingRecordButton(isRecording: viewModel.isRecording) {
                viewModel.startRecording()
            }
            .disabled(viewModel.isRecording || viewModel.isProcessing)

            if viewModel.isProcessing {
                ProgressView("Processing…")
            }

            Spacer()
            Spacer()
        }
        .alert(item: $viewModel.alert) { alert in
            switch alert {
            case .success:
                return Alert(
                    title: Text(alert.message),
                    dismissButton: .default(Text("OK")) {
                        dismiss()
                    }
                )
            case .failure:
                return Alert(
                    title: Text("Recording Rejected"),
                    message: Text(alert.message),
                    dismissButton: .default(Text("Re-record"))
                )
            case .permissionDenied:
                return Alert(
                    title: Text(alert.message),
                    primaryButton: .default(Text("Open Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        dismiss()
                    },
                    secondaryButton: .cancel {
                        dismiss()
                    }
                )
            }
        }
    }

    private var statusText: String {
        if viewModel.isProcessing {
            return "Analyzing the recording…"
        } else if viewModel.isRecording {
            return "Recording… tap the watermelon three times"
        } else {
            return "Hold the phone close to the watermelon\nand tap the button to start"
        }
    }
}
