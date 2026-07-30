//
//  SweetnessLabel.swift
//  WatermelonWhisperer
//

import SwiftUI

/// Maps a raw sweetness index to a user-facing label and color.
/// Boundaries are inclusive on the "Moderately Sweet" band: 10 and 11 both map there.
enum SweetnessLabel: String {
    case notSweet = "Not Sweet"
    case moderatelySweet = "Moderately Sweet"
    case verySweet = "Very Sweet"

    init(index: Float) {
        if index < 10 {
            self = .notSweet
        } else if index <= 11 {
            self = .moderatelySweet
        } else {
            self = .verySweet
        }
    }

    var color: Color {
        switch self {
        case .notSweet: return .gray
        case .moderatelySweet: return .orange
        case .verySweet: return .green
        }
    }
}
