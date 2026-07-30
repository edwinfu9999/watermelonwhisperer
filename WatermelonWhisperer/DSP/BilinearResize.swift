//
//  BilinearResize.swift
//  WatermelonWhisperer
//
//  Manual bilinear resize matching tf.image.resize's defaults: half-pixel
//  centers, no antialiasing, independent per-axis scaling (stretch to
//  square, no aspect-ratio preservation, no letterboxing).
//

import Foundation

/// Explicitly non-isolated: pure CPU computation that must run off the main actor.
nonisolated enum BilinearResize {
    /// Resizes an RGB Float32 buffer (row-major, height x width x 3, values 0-255)
    /// to `outHeight` x `outWidth` using TensorFlow's half-pixel-center bilinear formula:
    /// in_coord = (out_index + 0.5) * (inSize / outSize) - 0.5, clamped to [0, inSize - 1].
    static func resize(
        source: [Float],
        sourceHeight: Int,
        sourceWidth: Int,
        outHeight: Int,
        outWidth: Int,
        channels: Int = 3
    ) -> [Float] {
        precondition(source.count == sourceHeight * sourceWidth * channels)

        var output = [Float](repeating: 0, count: outHeight * outWidth * channels)
        let scaleY = Float(sourceHeight) / Float(outHeight)
        let scaleX = Float(sourceWidth) / Float(outWidth)

        func clampCoord(_ value: Float, maxIndex: Int) -> (low: Int, high: Int, frac: Float) {
            let clamped = max(0, min(value, Float(maxIndex)))
            let low = Int(clamped)
            let high = min(low + 1, maxIndex)
            let frac = clamped - Float(low)
            return (low, high, frac)
        }

        source.withUnsafeBufferPointer { src in
            output.withUnsafeMutableBufferPointer { dst in
                for oy in 0..<outHeight {
                    let inY = (Float(oy) + 0.5) * scaleY - 0.5
                    let (y0, y1, fy) = clampCoord(inY, maxIndex: sourceHeight - 1)

                    for ox in 0..<outWidth {
                        let inX = (Float(ox) + 0.5) * scaleX - 0.5
                        let (x0, x1, fx) = clampCoord(inX, maxIndex: sourceWidth - 1)

                        let rowY0 = y0 * sourceWidth
                        let rowY1 = y1 * sourceWidth
                        let idxTL = (rowY0 + x0) * channels
                        let idxTR = (rowY0 + x1) * channels
                        let idxBL = (rowY1 + x0) * channels
                        let idxBR = (rowY1 + x1) * channels
                        let outIdx = (oy * outWidth + ox) * channels

                        for c in 0..<channels {
                            let top = src[idxTL + c] * (1 - fx) + src[idxTR + c] * fx
                            let bottom = src[idxBL + c] * (1 - fx) + src[idxBR + c] * fx
                            dst[outIdx + c] = top * (1 - fy) + bottom * fy
                        }
                    }
                }
            }
        }

        return output
    }
}
