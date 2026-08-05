import Foundation

public enum ComparisonOperator: String, Codable, CaseIterable, Sendable {
    case greaterThan = "gt"
    case greaterThanOrEqual = "gte"
    case lessThan = "lt"
    case lessThanOrEqual = "lte"

    public var symbol: String {
        switch self {
        case .greaterThan: return ">"
        case .greaterThanOrEqual: return "≥"
        case .lessThan: return "<"
        case .lessThanOrEqual: return "≤"
        }
    }

    public func evaluate(_ lhs: Double, _ rhs: Double) -> Bool {
        switch self {
        case .greaterThan: return lhs > rhs
        case .greaterThanOrEqual: return lhs >= rhs
        case .lessThan: return lhs < rhs
        case .lessThanOrEqual: return lhs <= rhs
        }
    }
}

/// The "eğer" half of a rule: a boolean tree evaluated every frame against the
/// current signals and app context.
///
/// Conditions are separate from triggers on purpose. A trigger answers "did the
/// gesture happen?"; a condition answers "should it count right now?". Keeping
/// them apart is what lets the same tongue-down gesture scroll the feed, skip a
/// Reel, and do nothing at all inside a DM thread.
public indirect enum Condition: Hashable, Sendable {

    /// Always true. The default for a fresh rule.
    case always
    /// Every child must hold.
    case all([Condition])
    /// At least one child must hold.
    case any([Condition])
    /// Inverts its child.
    case not(Condition)

    /// Compare a live signal against a constant.
    case signal(Signal, ComparisonOperator, Double)
    /// Restrict to a specific part of Instagram.
    case surface(Surface)
    /// A user-defined boolean, flipped by `setFlag` / `toggleFlag` actions.
    case flag(name: String, equals: Bool)
    /// Local-time window, in minutes since midnight. Wraps around midnight when
    /// `start > end` (e.g. 22:00 → 07:00).
    case timeOfDay(startMinute: Int, endMinute: Int)
    /// True only while the named profile mode is active.
    case mode(String)

    public var displayName: String {
        switch self {
        case .always: return "Her zaman"
        case .all(let children): return "TÜMÜ (\(children.count))"
        case .any(let children): return "HERHANGİ BİRİ (\(children.count))"
        case .not: return "DEĞİL"
        case .signal(let signal, let op, let value):
            return "\(signal.displayName) \(op.symbol) \(String(format: "%.2f", value))"
        case .surface(let surface): return "Ekran = \(surface.displayName)"
        case .flag(let name, let equals): return "Bayrak \(name) = \(equals)"
        case .timeOfDay(let start, let end):
            return "Saat \(Self.format(minute: start))–\(Self.format(minute: end))"
        case .mode(let name): return "Mod = \(name)"
        }
    }

    private static func format(minute: Int) -> String {
        String(format: "%02d:%02d", (minute / 60) % 24, minute % 60)
    }

    /// Child conditions, for tree rendering in the editor.
    public var children: [Condition] {
        switch self {
        case .all(let children), .any(let children): return children
        case .not(let child): return [child]
        default: return []
        }
    }

    public var isGroup: Bool {
        switch self {
        case .all, .any, .not: return true
        default: return false
        }
    }
}

// MARK: - Evaluation

public extension Condition {

    /// Evaluates the tree. Pure function of `frame` + `context`, which keeps the
    /// whole condition system trivially testable.
    func evaluate(frame: SignalFrame, context: EvaluationContext) -> Bool {
        switch self {
        case .always:
            return true
        case .all(let children):
            return children.allSatisfy { $0.evaluate(frame: frame, context: context) }
        case .any(let children):
            return children.contains { $0.evaluate(frame: frame, context: context) }
        case .not(let child):
            return !child.evaluate(frame: frame, context: context)
        case .signal(let signal, let op, let value):
            return op.evaluate(frame[signal], value)
        case .surface(let surface):
            return context.surface == surface
        case .flag(let name, let equals):
            return context.flag(name) == equals
        case .timeOfDay(let start, let end):
            let now = context.minuteOfDay
            return start <= end ? (now >= start && now < end) : (now >= start || now < end)
        case .mode(let name):
            return context.mode == name
        }
    }
}

// MARK: - Codable

extension Condition: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, children, child, signal, op, value, surface, name, equals
        case startMinute, endMinute, mode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "always":
            self = .always
        case "all":
            self = .all(try container.decode([Condition].self, forKey: .children))
        case "any":
            self = .any(try container.decode([Condition].self, forKey: .children))
        case "not":
            self = .not(try container.decode(Condition.self, forKey: .child))
        case "signal":
            self = .signal(try container.decode(Signal.self, forKey: .signal),
                           try container.decode(ComparisonOperator.self, forKey: .op),
                           try container.decode(Double.self, forKey: .value))
        case "surface":
            self = .surface(try container.decode(Surface.self, forKey: .surface))
        case "flag":
            self = .flag(name: try container.decode(String.self, forKey: .name),
                         equals: try container.decodeIfPresent(Bool.self, forKey: .equals) ?? true)
        case "timeOfDay":
            self = .timeOfDay(startMinute: try container.decode(Int.self, forKey: .startMinute),
                              endMinute: try container.decode(Int.self, forKey: .endMinute))
        case "mode":
            self = .mode(try container.decode(String.self, forKey: .mode))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                   debugDescription: "Bilinmeyen koşul: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .always:
            try container.encode("always", forKey: .type)
        case .all(let children):
            try container.encode("all", forKey: .type)
            try container.encode(children, forKey: .children)
        case .any(let children):
            try container.encode("any", forKey: .type)
            try container.encode(children, forKey: .children)
        case .not(let child):
            try container.encode("not", forKey: .type)
            try container.encode(child, forKey: .child)
        case .signal(let signal, let op, let value):
            try container.encode("signal", forKey: .type)
            try container.encode(signal, forKey: .signal)
            try container.encode(op, forKey: .op)
            try container.encode(value, forKey: .value)
        case .surface(let surface):
            try container.encode("surface", forKey: .type)
            try container.encode(surface, forKey: .surface)
        case .flag(let name, let equals):
            try container.encode("flag", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(equals, forKey: .equals)
        case .timeOfDay(let start, let end):
            try container.encode("timeOfDay", forKey: .type)
            try container.encode(start, forKey: .startMinute)
            try container.encode(end, forKey: .endMinute)
        case .mode(let name):
            try container.encode("mode", forKey: .type)
            try container.encode(name, forKey: .mode)
        }
    }
}
