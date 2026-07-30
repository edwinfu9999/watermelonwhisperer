//
//  CaptureAlert.swift
//  WatermelonWhisperer
//
//  Shared alert state for the camera and audio recording flows.
//

import Foundation

enum CaptureAlert: Identifiable {
    case success(String)
    case failure(String)
    case permissionDenied(String)

    var id: String { message }

    var message: String {
        switch self {
        case .success(let message), .failure(let message), .permissionDenied(let message):
            return message
        }
    }
}
