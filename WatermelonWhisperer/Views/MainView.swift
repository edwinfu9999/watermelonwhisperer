//
//  MainView.swift
//  WatermelonWhisperer
//

import SwiftUI

struct MainView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: MainViewModel

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var showCamera = false
    @State private var showRecorder = false

    init(appState: AppState, predictorLoader: PredictorLoader) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: MainViewModel(
            appState: appState,
            predictorLoader: predictorLoader
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 16) {
                    CaptureButton(
                        title: "Take Picture",
                        systemImage: "camera.fill",
                        isComplete: appState.isImageValid
                    ) {
                        showCamera = true
                    }

                    CaptureButton(
                        title: "Record Tapping",
                        systemImage: "mic.fill",
                        isComplete: appState.isAudioValid
                    ) {
                        showRecorder = true
                    }
                }

                Button {
                    viewModel.calculateSweetness()
                } label: {
                    HStack(spacing: 10) {
                        if appState.isCalculating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Calculate Sweetness")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(appState.canCalculateSweetness ? Color.accentColor : Color.gray.opacity(0.35))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!appState.canCalculateSweetness)

                if let index = appState.sweetnessIndex {
                    ResultView(index: index)
                        .transition(.opacity)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
            .animation(.default, value: appState.sweetnessIndex)
            .navigationTitle("WatermelonWhisperer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showOnboarding = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Help")
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView(appState: appState)
            }
            .fullScreenCover(isPresented: $showRecorder) {
                AudioRecordingView(appState: appState)
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .onAppear {
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .alert("Error", isPresented: $appState.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(appState.errorMessage ?? "Something went wrong.")
            }
        }
    }
}
