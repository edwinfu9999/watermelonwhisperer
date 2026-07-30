//
//  OnboardingAudioPlayer.swift
//  WatermelonWhisperer
//
//  Plays the bundled reference_taps.wav sample during onboarding.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class OnboardingAudioPlayer: NSObject, ObservableObject {
    private var player: AVAudioPlayer?

    func playReferenceTaps() {
        guard let url = Bundle.main.url(forResource: "reference_taps", withExtension: "wav") else {
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            // Sample playback is a nice-to-have during onboarding; failures are non-blocking.
        }
    }
}
