import Foundation

/// Per-signal calibration captured by the calibration wizard.
///
/// Raw tracker values differ a lot between faces — some people can barely reach
/// `tongueOut == 0.6`, others sit at `0.2` at rest. The wizard records a neutral
/// value and a maximum-effort value per signal; the processor then rescales the
/// raw reading so that "neutral" maps to `0` and "full effort" maps to `1`.
public struct CalibrationRange: Codable, Hashable, Sendable {
    public var neutral: Double
    public var maximum: Double

    public init(neutral: Double = 0, maximum: Double = 1) {
        self.neutral = neutral
        self.maximum = maximum
    }

    /// Rescales a raw value into `0...1`. Degenerate ranges pass through.
    public func normalise(_ raw: Double) -> Double {
        let span = maximum - neutral
        guard span > 0.05 else { return min(max(raw, 0), 1) }
        return min(max((raw - neutral) / span, 0), 1)
    }
}

/// Tunable smoothing/gating parameters, exposed in Settings.
public struct SignalTuning: Codable, Hashable, Sendable {
    /// Exponential moving average factor, `0...1`. Higher = more responsive,
    /// lower = smoother but laggier.
    public var smoothing: Double
    /// Values below this are floored to zero, killing tracker jitter at rest.
    public var deadzone: Double
    /// `tongueOut` must exceed this before any directional tongue signal is
    /// allowed through.
    public var tongueGate: Double
    /// Minimum direction confidence before directional tongue signals pass.
    public var confidenceGate: Double

    public init(smoothing: Double = 0.35,
                deadzone: Double = 0.04,
                tongueGate: Double = 0.25,
                confidenceGate: Double = 0.3) {
        self.smoothing = smoothing
        self.deadzone = deadzone
        self.tongueGate = tongueGate
        self.confidenceGate = confidenceGate
    }

    public static let `default` = SignalTuning()
}

/// Turns raw tracker frames into the calibrated, smoothed, gated frames the
/// rule engine consumes.
///
/// This lives in Core (not the app layer) so it can be unit tested against
/// recorded frame sequences without ARKit.
public final class SignalProcessor {

    public private(set) var tuning: SignalTuning
    public private(set) var calibration: [Signal: CalibrationRange]

    private var smoothed: [Signal: Double] = [:]

    public init(tuning: SignalTuning = .default,
                calibration: [Signal: CalibrationRange] = [:]) {
        self.tuning = tuning
        self.calibration = calibration
    }

    public func update(tuning: SignalTuning) {
        self.tuning = tuning
    }

    public func update(calibration: [Signal: CalibrationRange]) {
        self.calibration = calibration
    }

    /// Clears smoothing history. Call when tracking is lost so a stale value
    /// cannot bleed into the next session.
    public func reset() {
        smoothed.removeAll()
    }

    public func process(_ frame: SignalFrame) -> SignalFrame {
        guard frame.hasFace else {
            reset()
            return SignalFrame.lost(at: frame.timestamp)
        }

        var output = SignalFrame(timestamp: frame.timestamp)
        output[.faceVisible] = 1

        // 1. Calibrate + smooth every signal.
        for signal in Signal.allCases where signal != .faceVisible {
            let raw = frame[signal]
            let calibrated = calibration[signal]?.normalise(raw) ?? min(max(raw, 0), 1)
            let previous = smoothed[signal] ?? calibrated
            let alpha = min(max(tuning.smoothing, 0.01), 1)
            var value = previous + (calibrated - previous) * alpha
            if value < tuning.deadzone { value = 0 }
            smoothed[signal] = value
            output[signal] = value
        }

        // 2. Gate directional tongue signals behind protrusion + confidence.
        //    Without this, the direction estimator's noise on a closed mouth
        //    would happily fire a "scroll" rule.
        let tongueOut = output[.tongueOut]
        let confidence = output[.tongueConfidence]
        if tongueOut < tuning.tongueGate || confidence < tuning.confidenceGate {
            for signal in Signal.allCases where signal.requiresTongueOut {
                output[signal] = 0
            }
        }

        return output
    }
}
