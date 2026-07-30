//
//  PulsingRecordButton.swift
//  WatermelonWhisperer
//

import SwiftUI

/// Large circular record button that animates with a pulsing ring while recording.
struct PulsingRecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.35))
                    .frame(width: 150, height: 150)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)

                Circle()
                    .fill(Color.red)
                    .frame(width: 104, height: 104)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.6), lineWidth: 3)
                    )
            }
        }
        .buttonStyle(.plain)
        .onAppear { isPulsing = isRecording }
        .onChange(of: isRecording) { recording in
            if recording {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                withAnimation(.default) {
                    isPulsing = false
                }
            }
        }
    }
}

#Preview {
    PulsingRecordButton(isRecording: true) {}
}
