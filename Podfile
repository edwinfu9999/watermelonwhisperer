platform :ios, '16.0'

target 'WatermelonWhisperer' do
  use_frameworks!

  pod 'TensorFlowLiteSwift', '~> 2.17.0'
  # The model uses ops (e.g. FlexTensorListReserve, from a dynamic-length RNN/list construct
  # the converter couldn't lower to a builtin op) that require the Flex/Select-TF-ops delegate.
  pod 'TensorFlowLiteSelectTfOps', '~> 2.17.0'

  target 'WatermelonWhispererTests' do
    inherit! :search_paths
  end
end

# NOTE: TensorFlowLiteSelectTfOps is a STATIC framework of pure C++ code. Linking it is not
# enough: without `-force_load` the linker discards all of its object files (nothing references
# them), the TF_AcquireFlexDelegate symbol never lands in the app, and TFLite's automatic Flex
# delegate attachment silently fails at runtime with "Select TensorFlow op(s) ... not supported".
# The app target's OTHER_LDFLAGS in the Xcode project therefore carries:
#   -force_load $(PODS_ROOT)/TensorFlowLiteSelectTfOps/Frameworks/TensorFlowLiteSelectTfOps.xcframework/ios-arm64/TensorFlowLiteSelectTfOps.framework/TensorFlowLiteSelectTfOps
# (This is the officially documented requirement for Select TF ops on iOS.) Do not remove it.
#
# NOTE: TensorFlowLiteSelectTfOps' xcframework only ships a device (arm64-iphoneos) slice for
# this release, not a simulator slice. Once it's linked in, the app (and its hosted unit test
# target) can only be built for a physical device — Simulator builds fail at link time with
# "building for iOS-simulator, but linking in object file ... built for iOS". There is no
# supported per-SDK conditional pod inclusion in CocoaPods that fixes this cleanly; attempting
# to strip the framework from the simulator link line via a post_install hook is fragile and
# was deliberately not done here. This is an acceptable tradeoff: the app requires a physical
# device anyway for camera/mic. To run just the unit tests (which never touch the model) on
# Simulator, temporarily comment out the TensorFlowLiteSelectTfOps line below and `pod install`.
