//
//  HapticFeedback.swift
//  WatermelonWhisperer
//

import UIKit

enum HapticFeedback {
    @MainActor static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
