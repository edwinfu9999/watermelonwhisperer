//
//  ImagePipeline.swift
//  WatermelonWhisperer
//
//  Vision-based watermelon detection + crop + resize + tensor prep.
//  Runs synchronously; callers are responsible for dispatching off the main thread.
//

import CoreGraphics
import UIKit
import Vision

protocol ImagePipelineProtocol {
    /// Returns a flattened [1, 224, 224, 3] Float32 tensor, raw 0-255 RGB, row-major.
    nonisolated func processImage(_ image: UIImage) throws -> [Float]
}

/// Explicitly non-isolated: this does CPU-heavy Vision/CoreGraphics work that must run on a
/// background thread via Task.detached, not implicitly hop to the main actor (the project's
/// default actor isolation is MainActor).
nonisolated final class ImagePipeline: ImagePipelineProtocol {
    enum Config {
        /// Sane default confidence floor for saliency/rectangle detections; not specified by the model contract.
        static let minimumConfidence: Float = 0.2
        /// ~2% of image dimension: reject boxes that touch the frame edge (watermelon likely cut off).
        static let edgeMarginFraction: CGFloat = 0.02
        /// Reject boxes covering less than 15% of the frame (too far away).
        static let minimumAreaFraction: CGFloat = 0.15
        /// Expand the detected box by 5% of its own size before cropping.
        static let paddingFraction: CGFloat = 0.05
        static let targetSize = 224
    }

    struct RawPixels {
        let pixels: [Float]
        let width: Int
        let height: Int
    }

    func processImage(_ image: UIImage) throws -> [Float] {
        let uprightImage = try Self.uprightCGImage(from: image)
        let boundingBoxPixels = try Self.detectWatermelon(in: uprightImage)
        let paddedBox = Self.pad(
            boundingBoxPixels,
            by: Config.paddingFraction,
            imageSize: CGSize(width: uprightImage.width, height: uprightImage.height)
        )

        guard paddedBox.width > 0, paddedBox.height > 0,
              let cropped = uprightImage.cropping(to: paddedBox) else {
            throw PipelineError.imageCropFailed
        }

        let raw = try Self.extractRGBFloats(from: cropped)
        return BilinearResize.resize(
            source: raw.pixels,
            sourceHeight: raw.height,
            sourceWidth: raw.width,
            outHeight: Config.targetSize,
            outWidth: Config.targetSize
        )
    }

    // MARK: - Orientation

    /// Bakes EXIF orientation into the pixel data so all subsequent Vision and
    /// coordinate math operates against an upright image. This must happen before
    /// Vision runs — reading the raw `.cgImage` from a photo captured in any
    /// orientation but portrait would otherwise silently misplace the bounding box.
    static func uprightCGImage(from image: UIImage) throws -> CGImage {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let cgImage = rendered.cgImage else {
            throw PipelineError.orientationFixFailed
        }
        return cgImage
    }

    // MARK: - Detection

    static func detectWatermelon(in cgImage: CGImage) throws -> CGRect {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        try? handler.perform([saliencyRequest])

        if let observation = saliencyRequest.results?.first,
           let best = observation.salientObjects?.max(by: { $0.confidence < $1.confidence }) {
            guard best.confidence >= Config.minimumConfidence else {
                throw PipelineError.saliencyConfidenceTooLow
            }
            try validate(best.boundingBox)
            return pixelRect(from: best.boundingBox, imageWidth: cgImage.width, imageHeight: cgImage.height)
        }

        // Fallback: saliency found nothing usable.
        let rectanglesRequest = VNDetectRectanglesRequest()
        rectanglesRequest.minimumConfidence = 0.3
        rectanglesRequest.minimumAspectRatio = 0.2
        try? handler.perform([rectanglesRequest])

        guard let rectangle = rectanglesRequest.results?.first else {
            throw PipelineError.noSalientObjectFound
        }
        guard rectangle.confidence >= Config.minimumConfidence else {
            throw PipelineError.saliencyConfidenceTooLow
        }
        try validate(rectangle.boundingBox)
        return pixelRect(from: rectangle.boundingBox, imageWidth: cgImage.width, imageHeight: cgImage.height)
    }

    /// `box` is Vision's normalized, bottom-left-origin rect.
    private static func validate(_ box: CGRect) throws {
        let margin = Config.edgeMarginFraction
        if box.minX < margin || box.minY < margin || box.maxX > (1 - margin) || box.maxY > (1 - margin) {
            throw PipelineError.objectTouchesEdge
        }
        if box.width * box.height < Config.minimumAreaFraction {
            throw PipelineError.objectTooSmall
        }
    }

    /// Converts Vision's normalized, bottom-left-origin rect to pixel coordinates
    /// with a top-left origin, matching CGImage/CGContext pixel space.
    private static func pixelRect(from normalizedBox: CGRect, imageWidth: Int, imageHeight: Int) -> CGRect {
        let w = CGFloat(imageWidth)
        let h = CGFloat(imageHeight)
        let x = normalizedBox.origin.x * w
        let y = (1 - normalizedBox.origin.y - normalizedBox.height) * h
        return CGRect(x: x, y: y, width: normalizedBox.width * w, height: normalizedBox.height * h)
    }

    private static func pad(_ rect: CGRect, by fraction: CGFloat, imageSize: CGSize) -> CGRect {
        let expanded = rect.insetBy(dx: -rect.width * fraction, dy: -rect.height * fraction)
        let minX = max(0, expanded.origin.x)
        let minY = max(0, expanded.origin.y)
        let maxX = min(imageSize.width, expanded.maxX)
        let maxY = min(imageSize.height, expanded.maxY)
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY)).integral
    }

    // MARK: - Pixel extraction

    private static func extractRGBFloats(from cgImage: CGImage) throws -> RawPixels {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { throw PipelineError.imageCropFailed }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var rawBytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        try rawBytes.withUnsafeMutableBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else {
                throw PipelineError.imageCropFailed
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        var floats = [Float](repeating: 0, count: width * height * 3)
        for i in 0..<(width * height) {
            let srcOffset = i * 4
            let dstOffset = i * 3
            floats[dstOffset] = Float(rawBytes[srcOffset])
            floats[dstOffset + 1] = Float(rawBytes[srcOffset + 1])
            floats[dstOffset + 2] = Float(rawBytes[srcOffset + 2])
        }
        return RawPixels(pixels: floats, width: width, height: height)
    }
}
