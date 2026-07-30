//
//  OnboardingView.swift
//  WatermelonWhisperer
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @StateObject private var audioPlayer = OnboardingAudioPlayer()

    var body: some View {
        VStack {
            Text("How to Use Watermelon Whisperer")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 32)

            TabView(selection: $currentPage) {
                PhotoTipPage()
                    .tag(0)
                TapTipPage(onPlaySample: { audioPlayer.playReferenceTaps() })
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(currentPage == 0 ? "Next" : "Get Started") {
                if currentPage == 0 {
                    withAnimation {
                        currentPage = 1
                    }
                } else {
                    hasSeenOnboarding = true
                    isPresented = false
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 24)
        }
    }
}

private struct PhotoTipPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("ReferencePhoto")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 4)
            Text("Step 1: Take a picture of the watermelon")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            VStack(alignment: .leading, spacing: 8) {
                Text("- Use a clean background")
                Text("- Ensure the watermelon fills the screen")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

private struct TapTipPage: View {
    let onPlaySample: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 90))
                .foregroundStyle(.tint)
            Text("Step 2: Record 3 thumps of the watermelon")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("Hit the watermelon 3 times around 0.5 seconds apart")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onPlaySample) {
                Label("Play Example", systemImage: "play.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.bordered)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
