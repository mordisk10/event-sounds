import Foundation

/// Mutable, shared boolean state that conditions read and actions write.
///
/// A reference type because rules must observe flag writes made by rules that
/// fired earlier in the same frame — that ordering is what makes mode switching
/// ("dil sağa → gezinme modu") behave predictably.
public final class FlagRegistry: @unchecked Sendable {

    private var storage: [String: Bool]
    private let lock = NSLock()

    public init(_ initial: [String: Bool] = [:]) {
        storage = initial
    }

    public func value(for name: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return storage[name] ?? false
    }

    public func set(_ name: String, to value: Bool) {
        lock.lock(); defer { lock.unlock() }
        storage[name] = value
    }

    @discardableResult
    public func toggle(_ name: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let next = !(storage[name] ?? false)
        storage[name] = next
        return next
    }

    public var snapshot: [String: Bool] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    public func replaceAll(with values: [String: Bool]) {
        lock.lock(); defer { lock.unlock() }
        storage = values
    }
}

/// Everything a condition needs to know beyond the raw signals.
public struct EvaluationContext: Sendable {

    /// Which Instagram screen is on display right now.
    public var surface: Surface
    /// The active profile mode, e.g. `"varsayilan"` or `"eller-serbest"`.
    public var mode: String
    /// Minutes since local midnight, `0..<1440`.
    public var minuteOfDay: Int
    /// Shared flag storage.
    public var flags: FlagRegistry

    public init(surface: Surface = .unknown,
                mode: String = "varsayilan",
                minuteOfDay: Int = 0,
                flags: FlagRegistry = FlagRegistry()) {
        self.surface = surface
        self.mode = mode
        self.minuteOfDay = minuteOfDay
        self.flags = flags
    }

    public func flag(_ name: String) -> Bool {
        flags.value(for: name)
    }

    /// Builds a context for "now" using the supplied calendar/date, so tests can
    /// pin the clock.
    public static func current(surface: Surface,
                               mode: String,
                               flags: FlagRegistry,
                               date: Date = Date(),
                               calendar: Calendar = .current) -> EvaluationContext {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return EvaluationContext(surface: surface, mode: mode, minuteOfDay: minute, flags: flags)
    }
}
