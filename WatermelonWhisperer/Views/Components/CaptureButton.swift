//
//  CaptureButton.swift
//  WatermelonWhisperer
//

import SwiftUI

/// A main-screen action row with a trailing checkmark badge once its input is valid.
struct CaptureButton: View {
    let title: String
    let systemImage: String
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 28)
                Text(title)
                    .font(.body.weight(.medium))
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .animation(.default, value: isComplete)
    }
}
