#if canImport(Vision)
import Vision
import CoreML
import CoreImage
import CoreVideo
import CoreGraphics

/// Shared imaging constants.
///
/// Every stage of the tongue pipeline must agree on one orientation, otherwise
/// the mouth rectangle found by Vision and the pixels sampled by the fallback
/// detector describe different images — and the up/down axis silently inverts,
/// which is the one axis this whole project depends on.
enum InstakaiVision {
    /// The front camera on iPhone delivers a landscape buffer while the app is
    /// held in portrait, and the image is mirrored. Vision needs to be told.
    static let orientation: CGImagePropertyOrientation = .leftMirrored

    /// Reused across detections; creating a `CIContext` per frame is expensive.
    static let ciContext = CIContext(options: [.cacheIntermediates: false])
}

/// Uses a bundled Core ML object detector to find the tongue tip.
///
/// The model is optional. Drop a Create ML object-detection model named
/// `TongueTip.mlmodel` into the app target (single class, `tongue`) and this
/// detector takes over automatically; otherwise the app falls back to
/// `PixelStatisticsTongueTipDetector`. `docs/GESTURES.md` covers dataset capture.
final class CoreMLTongueTipDetector: TongueTipLocating {

    private let request: VNCoreMLRequest

    private init(model: VNCoreMLModel) {
        request = VNCoreMLRequest(model: model)
        // The mouth crop is already roughly square; scaleFill avoids the
        // letterboxing that would bias the predicted centre.
        request.imageCropAndScaleOption = .scaleFill
    }

    static func makeIfAvailable() -> CoreMLTongueTipDetector? {
        guard let url = Bundle.main.url(forResource: "TongueTip", withExtension: "mlmodelc"),
              let coreModel = try? MLModel(contentsOf: url),
              let visionModel = try? VNCoreMLModel(for: coreModel) else {
            return nil
        }
        return CoreMLTongueTipDetector(model: visionModel)
    }

    func locate(in pixelBuffer: CVPixelBuffer, mouthRect: CGRect) -> TongueObservation? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: InstakaiVision.orientation)
        request.regionOfInterest = mouthRect
        guard (try? handler.perform([request])) != nil else { return nil }

        guard let best = (request.results as? [VNRecognizedObjectObservation])?
                .max(by: { $0.confidence < $1.confidence }),
              best.confidence > 0.25 else {
            return nil
        }

        // Vision observations are full-image normalised with a bottom-left
        // origin, the same space `mouthRect` is expressed in.
        let tip = CGPoint(x: best.boundingBox.midX, y: best.boundingBox.midY)
        return TongueObservation(offset: normaliseOffset(tip: tip, mouthRect: mouthRect),
                                 confidence: Double(best.confidence))
    }
}

/// Fallback detector that needs no trained model.
///
/// It finds the tongue by colour: inside the mouth region the tongue is the
/// brightest strongly-red area, while the oral cavity behind it is dark and the
/// lips are narrower. We take a redness-weighted centroid and use the fraction
/// of qualifying pixels as confidence.
///
/// This is the weakest link in the pipeline by design — it degrades in low light
/// and with heavy lipstick. The Core ML path exists so it can be replaced with
/// something trained, without any other file changing.
final class PixelStatisticsTongueTipDetector: TongueTipLocating {

    /// Longest edge of the downsampled crop. A centroid does not need detail,
    /// and this runs on every analysed frame.
    private let sampleSize = 48
    /// Minimum share of qualifying pixels before the reading is believed.
    private let minimumCoverage = 0.02
    /// Coverage at which confidence saturates at 1.
    private let saturationCoverage = 0.18

    func locate(in pixelBuffer: CVPixelBuffer, mouthRect: CGRect) -> TongueObservation? {
        // Orient first, so the crop uses the same space Vision reported.
        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(InstakaiVision.orientation)
        let extent = oriented.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        // CIImage and Vision share a bottom-left origin, so the rect maps across
        // directly.
        let cropRect = CGRect(x: extent.minX + mouthRect.minX * extent.width,
                              y: extent.minY + mouthRect.minY * extent.height,
                              width: mouthRect.width * extent.width,
                              height: mouthRect.height * extent.height)
            .integral
            .intersection(extent)
        guard !cropRect.isNull, cropRect.width >= 4, cropRect.height >= 4 else { return nil }

        let cropped = oriented.cropped(to: cropRect)
        guard let cgImage = InstakaiVision.ciContext.createCGImage(cropped, from: cropRect) else {
            return nil
        }

        // Draw into our own bitmap so the memory layout is unambiguous: a
        // CGBitmapContext stores row 0 as the *top* row of the drawn image, so
        // increasing y in the buffer means moving down the face.
        let scale = CGFloat(sampleSize) / max(cropRect.width, cropRect.height)
        let width = max(Int((cropRect.width * scale).rounded()), 1)
        let height = max(Int((cropRect.height * scale).rounded()), 1)
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        let drawn: Bool = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let context = CGContext(data: base,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var weightedX = 0.0
        var weightedY = 0.0
        var totalWeight = 0.0
        var qualifying = 0
        let inspected = width * height

        for y in 0..<height {
            let rowStart = y * bytesPerRow
            for x in 0..<width {
                let index = rowStart + x * 4
                let red = Double(pixels[index])
                let green = Double(pixels[index + 1])
                let blue = Double(pixels[index + 2])

                let brightness = (red + green + blue) / 3
                guard brightness > 45 else { continue }
                // Redness relative to the strongest other channel. The tongue
                // sits well above the mouth interior on this measure.
                let redness = (red - max(green, blue)) / max(red, 1)
                guard redness > 0.18 else { continue }

                let weight = redness * brightness
                weightedX += Double(x) * weight
                weightedY += Double(y) * weight
                totalWeight += weight
                qualifying += 1
            }
        }

        guard totalWeight > 0 else { return nil }
        let coverage = Double(qualifying) / Double(inspected)
        guard coverage >= minimumCoverage else { return nil }

        // Centroid in crop-local coordinates, mapped to −1…1 with +y downwards.
        let centroidX = weightedX / totalWeight
        let centroidY = weightedY / totalWeight
        let offset = CGPoint(x: (centroidX / Double(width)) * 2 - 1,
                             y: (centroidY / Double(height)) * 2 - 1)

        return TongueObservation(offset: offset,
                                 confidence: min(coverage / saturationCoverage, 1))
    }
}

/// Converts a tip position in full-image normalised (bottom-left origin)
/// coordinates into an offset from the mouth centre, scaled so ±1 is the edge of
/// the search region.
///
/// The Y axis is flipped on the way out so positive means "down the face",
/// matching how rules are written.
func normaliseOffset(tip: CGPoint, mouthRect: CGRect) -> CGPoint {
    let halfWidth = max(mouthRect.width / 2, 0.0001)
    let halfHeight = max(mouthRect.height / 2, 0.0001)
    return CGPoint(x: (tip.x - mouthRect.midX) / halfWidth,
                   y: -(tip.y - mouthRect.midY) / halfHeight)
}
#endif
