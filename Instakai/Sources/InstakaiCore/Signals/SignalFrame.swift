import Foundation

/// One tick of tracker output: every signal the tracker could measure, plus the
/// timestamp it was measured at.
///
/// `SignalFrame` is a value type on purpose — it is produced on the ARKit
/// delegate queue and consumed on the engine queue, and copying ~30 doubles is
/// cheaper than any form of synchronisation.
public struct SignalFrame: Codable, Hashable, Sendable {

    /// Monotonic timestamp in seconds (ARKit frame time, not wall clock).
    public var timestamp: TimeInterval

    /// Raw measured values keyed by signal. Missing keys read back as `0`.
    public private(set) var values: [Signal: Double]

    public init(timestamp: TimeInterval, values: [Signal: Double] = [:]) {
        self.timestamp = timestamp
        self.values = values
    }

    public subscript(signal: Signal) -> Double {
        get { values[signal] ?? 0 }
        set { values[signal] = newValue }
    }

    /// `true` when the tracker currently has a face.
    public var hasFace: Bool { self[.faceVisible] >= 0.5 }

    /// An empty frame, used when tracking is lost.
    public static func lost(at timestamp: TimeInterval) -> SignalFrame {
        SignalFrame(timestamp: timestamp, values: [.faceVisible: 0])
    }

    /// Returns a copy with every value clamped into its valid range.
    public func clamped() -> SignalFrame {
        var copy = self
        for (signal, value) in values {
            copy.values[signal] = min(max(value, 0), 1)
        }
        return copy
    }

    /// Merges `other` on top of the receiver. Used to fold the tongue direction
    /// estimate (which runs at a lower cadence) into the ARKit blend-shape frame.
    public func merging(_ other: SignalFrame) -> SignalFrame {
        var copy = self
        for (signal, value) in other.values {
            copy.values[signal] = value
        }
        return copy
    }
}

// MARK: - Codable

extension SignalFrame {
    private enum CodingKeys: String, CodingKey {
        case timestamp, values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        let raw = try container.decodeIfPresent([String: Double].self, forKey: .values) ?? [:]
        var mapped: [Signal: Double] = [:]
        for (key, value) in raw {
            if let signal = Signal(rawValue: key) { mapped[signal] = value }
        }
        values = mapped
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        var raw: [String: Double] = [:]
        for (signal, value) in values { raw[signal.rawValue] = value }
        try container.encode(raw, forKey: .values)
    }
}
