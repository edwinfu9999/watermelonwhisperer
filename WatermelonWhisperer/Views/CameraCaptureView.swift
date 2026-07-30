//
//  CameraCaptureView.swift
//  WatermelonWhisperer
//

import SwiftUI

struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CameraViewModel

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: CameraViewModel(appState: appState))
    }

    var body: some View {
        ZStack {
            CameraPreviewView(previewLayer: viewModel.cameraService.previewLayer)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        viewModel.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .padding()
                    Spacer()
                }

                Spacer()

                Button {
                    viewModel.capture()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(.white)
                            .frame(width: 64, height: 64)
                    }
                }
                .disabled(viewModel.isProcessing)
                .padding(.bottom, 44)
            }

            if viewModel.isProcessing {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.6)
            }
        }
        .statusBarHidden()
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
        .alert(item: $viewModel.alert) { alert in
            switch alert {
            case .success:
                return Alert(
                    title: Text(alert.message),
                    dismissButton: .default(Text("OK")) {
                        viewModel.stopSession()
                        dismiss()
                    }
                )
            case .failure:
                return Alert(
                    title: Text("Retake Photo"),
                    message: Text(alert.message),
                    dismissButton: .default(Text("Retake"))
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
}
