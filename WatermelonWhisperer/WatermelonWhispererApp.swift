//
//  WatermelonWhispererApp.swift
//  WatermelonWhisperer
//

import SwiftUI

@main
struct WatermelonWhispererApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var predictorLoader = PredictorLoader()

    var body: some Scene {
        WindowGroup {
            MainView(appState: appState, predictorLoader: predictorLoader)
        }
    }
}
