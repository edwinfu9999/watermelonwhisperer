# WatermelonWhisperer

Predicts watermelon sweetness from a photo and three taps, using a bundled TensorFlow Lite model (`watermelonClass.tflite`) with an image input, an audio spectrogram input, and a single raw sweetness-index output.

## Drop in your real assets

The project ships with placeholders so it builds and runs out of the box. Replace these before shipping:

| What | Where | Placeholder in repo |
|---|---|---|
| TFLite model | `WatermelonWhisperer/watermelonClass.tflite` (add the file here — it doesn't exist yet) | none — until added, the app shows a graceful "model could not be found" error instead of crashing |
| Reference photo | `WatermelonWhisperer/Assets.xcassets/ReferencePhoto.imageset/ReferencePhoto.png` | solid green square |
| Reference tap audio | `WatermelonWhisperer/Resources/reference_taps.wav` | synthetic 3-click placeholder (16 kHz mono) |

To add `watermelonClass.tflite`: drag it into the `WatermelonWhisperer/` folder in Xcode's navigator (or just drop the file into that folder on disk — this project uses Xcode 16's synchronized folder groups, so anything placed under `WatermelonWhisperer/` is automatically part of the app target, no manual "Target Membership" checkbox needed). Same for the reference photo and WAV — just overwrite the placeholder files in place.

## Build

Requires Xcode 16+ and CocoaPods (`sudo gem install cocoapods` if you don't have it).

```bash
cd WatermelonWhisperer
pod install
open WatermelonWhisperer.xcworkspace   # always the .xcworkspace, not the .xcodeproj, once Pods are installed
```

Then build/run the `WatermelonWhisperer` scheme. TensorFlow Lite is pulled in via CocoaPods (`pod 'TensorFlowLiteSwift'`) — there is currently no officially Google-maintained Swift Package Manager distribution of TensorFlowLiteSwift, so CocoaPods is the supported path here.

If your model needs ops outside TFLite's builtin set (e.g. it errors with `Didn't find op for builtin opcode` or `Select TensorFlow op(s) ... are not supported`), see `Podfile` — `TensorFlowLiteSelectTfOps` (the Flex delegate) is already included as a dependency for this reason. Two things must both be true for it to work: the pod is in the Podfile, **and** the app target's Other Linker Flags contain the `-force_load` entry for its framework binary (already configured in this project — see the note in `Podfile`). Expect a much larger binary and slower link times with this pod; that's the cost of bundling the TensorFlow kernels the model's LSTM layer needs.

Unit tests run via the `WatermelonWhispererTests` target (`Cmd+U`, or `xcodebuild test`) and don't require the real model/audio/photo assets — they exercise the DSP and label-mapping logic directly.

## Test on a physical device

**Camera and microphone capture do not work in the iOS Simulator.** Onboarding, layout, and error-handling paths (e.g. a missing model file) can be exercised in the simulator, but the actual photo-capture and tap-recording flows require a real iPhone or iPad with a development team selected in the target's signing settings.

**Simulator builds only work if `TensorFlowLiteSelectTfOps` is removed from the Podfile.** That pod's xcframework ships a device-only binary slice (no simulator slice), so once it's linked in — which it is, to support the model's ops — the app and its hosted `WatermelonWhispererTests` target can only be built for a physical device; a Simulator build/run/test will fail at link time (`building for iOS-simulator, but linking in object file ... built for iOS`). This isn't a project misconfiguration, it's a gap in Google's published binary. If you need to run just the unit tests on Simulator, comment out the `TensorFlowLiteSelectTfOps` line in the `Podfile`, run `pod install`, run the tests, then revert.

## Architecture

MVVM with protocol-backed services so pipelines are unit-testable without hardware:

- `Services/CameraService`, `Services/AudioRecorderService` — AVFoundation capture
- `Services/ImagePipeline` — Vision saliency detection, crop, bilinear resize, tensor prep
- `Services/AudioPipeline` — SNR guardrail, onset detection/validation, 2 s crop, STFT tensor prep
- `Services/SweetnessPredictor` — TFLite interpreter wrapper (loads once, reused for every prediction)
- `DSP/` — STFT (vDSP), onset/SNR math, bilinear resize — all pure, `nonisolated`, and unit-tested independent of UI
- `ViewModels/`, `Views/` — SwiftUI, MVVM; all DSP/inference work runs off the main actor via `Task.detached`

See the model I/O contract documented in the doc comments of `SweetnessPredictor.swift`, `AudioPipeline.swift`, and `ImagePipeline.swift` for the exact tensor shapes and preprocessing conventions each pipeline stage must produce.
