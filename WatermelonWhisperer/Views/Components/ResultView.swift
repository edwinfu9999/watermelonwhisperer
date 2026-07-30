//
//  ResultView.swift
//  WatermelonWhisperer
//

import SwiftUI

struct ResultView: View {
    let index: Float

    private var label: SweetnessLabel { SweetnessLabel(index: index) }

    var body: some View {
        VStack(spacing: 10) {
            Text(String(format: "%.2f", index))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label.rawValue)
                .font(.headline)
                .foregroundStyle(label.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(label.color.opacity(0.15), in: Capsule())
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack(spacing: 24) {
        ResultView(index: 8.4)
        ResultView(index: 10.5)
        ResultView(index: 12.9)
    }
}
