import Foundation

/// How a satisfied trigger converts into fire events.
public enum FireMode: Codable, Hashable, Sendable {
    /// Fires once on the rising edge, then must be released before firing again.
    case edge
    /// Fires once on the rising edge, then keeps firing every `interval`
    /// seconds while still held. This is what makes "hold the tongue down to
    /// keep scrolling" work.
    case repeating(interval: TimeInterval)
    /// Fires on the *falling* edge, i.e. when the gesture is released. Useful
    /// for "tap" style gestures where you want to distinguish short from long.
    case release
}

/// The condition that a gesture must satisfy, plus the timing envelope around it.
///
/// A trigger is deliberately a plain value: the engine keeps all mutable state
/// in `TriggerStateMachine`, so a trigger can be edited live in the UI without
/// disturbing whatever gesture is currently in flight.
public struct GestureTrigger: Codable, Hashable, Sendable {

    /// The signal being watched.
    public var signal: Signal

    /// Value the signal must exceed to be considered "active".
    public var threshold: Double

    /// Value the signal must drop below to be considered "released". Keeping
    /// this lower than `threshold` gives hysteresis, which stops a signal
    /// hovering exactly on the threshold from machine-gunning events.
    public var releaseThreshold: Double

    /// The signal must stay active for at least this long before the trigger
    /// fires. Filters out accidental twitches.
    public var minimumHold: TimeInterval

    /// If set, the gesture must be released within this window to count. Lets
    /// you bind different actions to a short tongue-out versus a long one.
    public var maximumHold: TimeInterval?

    /// How many times the gesture must be repeated within `repeatWindow` before
    /// firing. `1` is a single gesture, `2` is a "double tap".
    public var repeatCount: Int

    /// The window in which `repeatCount` repetitions must happen.
    public var repeatWindow: TimeInterval

    public var fireMode: FireMode

    public init(signal: Signal,
                threshold: Double = 0.5,
                releaseThreshold: Double = 0.35,
                minimumHold: TimeInterval = 0.12,
                maximumHold: TimeInterval? = nil,
                repeatCount: Int = 1,
                repeatWindow: TimeInterval = 0.8,
                fireMode: FireMode = .edge) {
        self.signal = signal
        self.threshold = threshold
        self.releaseThreshold = min(releaseThreshold, threshold)
        self.minimumHold = minimumHold
        self.maximumHold = maximumHold
        self.repeatCount = max(repeatCount, 1)
        self.repeatWindow = repeatWindow
        self.fireMode = fireMode
    }

    /// Short human summary shown in the rule list, e.g.
    /// "Dil aşağı > 0.55, 0.12sn basılı, tekrarlı".
    public var summary: String {
        var parts = ["\(signal.displayName) > \(String(format: "%.2f", threshold))"]
        if minimumHold > 0 {
            parts.append("\(String(format: "%.2f", minimumHold))sn basılı")
        }
        if repeatCount > 1 {
            parts.append("\(repeatCount)x")
        }
        switch fireMode {
        case .edge: break
        case .repeating(let interval):
            parts.append("her \(String(format: "%.2f", interval))sn tekrar")
        case .release:
            parts.append("bırakınca")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - FireMode Codable

extension FireMode {
    private enum CodingKeys: String, CodingKey { case type, interval }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "edge":
            self = .edge
        case "repeating":
            self = .repeating(interval: try container.decode(TimeInterval.self, forKey: .interval))
        case "release":
            self = .release
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                   debugDescription: "Bilinmeyen tetikleme modu: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .edge:
            try container.encode("edge", forKey: .type)
        case .repeating(let interval):
            try container.encode("repeating", forKey: .type)
            try container.encode(interval, forKey: .interval)
        case .release:
            try container.encode("release", forKey: .type)
        }
    }
}
