#if canImport(Vision) && canImport(ARKit)
import Vision
import ARKit
import CoreVideo
import CoreGraphics
import InstakaiCore

/// Where the tongue tip is, relative to the mouth.
struct TongueObservation {
    /// Offset from the mouth centre, normalised by mouth size and rotated into
    /// face space. `x` is positive towards the user's right, `y` positive down.
    var offset: CGPoint
    /// `0...1`, how much to trust this reading.
    var confidence: Double
}

/// Locates the tongue tip inside a mouth region.
///
/// Two implementations ship: a Core ML object detector (if a model is bundled)
/// and a pixel-statistics fallback. The protocol exists so the model can be
/// swapped without touching the estimator.
protocol TongueTipLocating: AnyObject {
    func locate(in pixelBuffer: CVPixelBuffer, mouthRect: CGRect) -> TongueObservation?
}

/// Estimates which way the tongue is pointing, and folds the result into a
/// `SignalFrame` as `tongueUp/Down/Left/Right`.
///
/// ### Why this exists
/// ARKit's face tracking reports `tongueOut` as a single 0–1 magnitude — it has
/// no notion of direction. Everything this project is built around ("dil aşağı →
/// kaydır") needs direction, so we derive it ourselves:
///
/// 1. Vision's face-landmark request gives the inner-lip polygon each cycle.
/// 2. A tongue-tip locator finds the tip inside that polygon.
/// 3. The offset from the mouth centre, normalised by mouth width/height and
///    de-rotated by the head roll, becomes the direction vector.
///
/// Landmark detection is the expensive part, so it runs on its own serial queue
/// at a reduced cadence and the most recent result is reused between runs.
final class TongueDirectionEstimator {

    /// Run the Vision pipeline every Nth ARKit frame. ARKit delivers 60fps;
    /// every 3rd frame is 20Hz, which is well above gesture speed and leaves
    /// the CPU budget for the web view.
    private let frameStride: Int

    private let locator: TongueTipLocating
    private let queue = DispatchQueue(label: "com.instakai.tongue-direction", qos: .userInitiated)
    private let landmarkRequest = VNDetectFaceLandmarksRequest()

    private var frameCounter = 0
    private var isRunning = false
    /// Guarded by `stateLock`; read from the ARKit delegate queue.
    private var latest: TongueObservation?
    private let stateLock = NSLock()

    init(locator: TongueTipLocating? = nil, frameStride: Int = 3) {
        self.frameStride = max(frameStride, 1)
        self.locator = locator ?? CoreMLTongueTipDetector.makeIfAvailable() ?? PixelStatisticsTongueTipDetector()
    }

    func reset() {
        stateLock.lock(); latest = nil; stateLock.unlock()
        frameCounter = 0
    }

    /// Submits a camera frame. Returns immediately; results land in `latest`.
    func submit(pixelBuffer: CVPixelBuffer, headRoll: Float) {
        frameCounter += 1
        guard frameCounter % frameStride == 0 else { return }

        stateLock.lock()
        let busy = isRunning
        if !busy { isRunning = true }
        stateLock.unlock()
        // Dropping frames while a previous one is still in flight keeps latency
        // bounded instead of building a backlog.
        guard !busy else { return }

        queue.async { [weak self] in
            guard let self else { return }
            let observation = self.analyse(pixelBuffer: pixelBuffer, headRoll: headRoll)
            self.stateLock.lock()
            self.latest = observation
            self.isRunning = false
            self.stateLock.unlock()
        }
    }

    /// Folds the most recent direction estimate into `frame`.
    func decorate(_ frame: SignalFrame) -> SignalFrame {
        stateLock.lock()
        let observation = latest
        stateLock.unlock()

        var output = frame
        guard let observation else {
            output[.tongueConfidence] = 0
            return output
        }

        let magnitude = frame[.tongueOut]
        output[.tongueConfidence] = observation.confidence
        // Directional strength is the offset scaled by how far the tongue is
        // actually out — a barely visible tongue cannot produce a strong signal
        // no matter how confidently we located its tip.
        output[.tongueRight] = clamp(Double(observation.offset.x)) * magnitude
        output[.tongueLeft] = clamp(Double(-observation.offset.x)) * magnitude
        output[.tongueDown] = clamp(Double(observation.offset.y)) * magnitude
        output[.tongueUp] = clamp(Double(-observation.offset.y)) * magnitude
        return output
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    // MARK: - Vision pipeline

    private func analyse(pixelBuffer: CVPixelBuffer, headRoll: Float) -> TongueObservation? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: InstakaiVision.orientation)
        do {
            try handler.perform([landmarkRequest])
        } catch {
            return nil
        }

        guard let face = (landmarkRequest.results)?.first,
              let innerLips = face.landmarks?.innerLips,
              innerLips.pointCount >= 4 else {
            return nil
        }

        // Landmark points are normalised to the face bounding box; lift them
        // into full-image normalised coordinates.
        let box = face.boundingBox
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for point in innerLips.normalizedPoints {
            let x = box.origin.x + CGFloat(point.x) * box.width
            let y = box.origin.y + CGFloat(point.y) * box.height
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }

        // The tongue leaves the mouth, so search a region taller than the lips.
        let lipWidth = max(maxX - minX, 0.01)
        let lipHeight = max(maxY - minY, 0.01)
        let searchRect = CGRect(x: minX - lipWidth * 0.15,
                                y: minY - lipHeight * 1.1,
                                width: lipWidth * 1.3,
                                height: lipHeight * 3.2)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !searchRect.isNull, searchRect.width > 0, searchRect.height > 0 else { return nil }

        guard let raw = locator.locate(in: pixelBuffer, mouthRect: searchRect) else { return nil }

        // `raw.offset` arrives in image space relative to the mouth centre and
        // scaled by mouth size. Rotate it by -roll so a tilted head still maps
        // "down the chin" to `tongueDown`.
        let angle = CGFloat(-headRoll)
        let cosA = cos(angle), sinA = sin(angle)
        let rotated = CGPoint(x: raw.offset.x * cosA - raw.offset.y * sinA,
                              y: raw.offset.x * sinA + raw.offset.y * cosA)

        return TongueObservation(offset: rotated, confidence: raw.confidence)
    }
}
#endif
