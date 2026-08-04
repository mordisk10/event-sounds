import Foundation

/// A named, reusable sequence of actions.
///
/// Macros are the composable unit of the generator: a rule points at a macro,
/// and macros can call other macros, so a user can build "beğen ve sonrakine
/// geç" once and reference it from three different gestures.
public struct Macro: Identifiable, Codable, Hashable, Sendable {
    /// Stable, user-visible identifier (e.g. `scroll-next-reel`). Referenced by
    /// `MacroAction.runMacro`.
    public var id: String
    public var name: String
    public var notes: String
    public var actions: [MacroAction]
    /// Built-in macros ship with the app and cannot be deleted, only copied.
    public var isBuiltIn: Bool

    public init(id: String,
                name: String,
                notes: String = "",
                actions: [MacroAction],
                isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.notes = notes
        self.actions = actions
        self.isBuiltIn = isBuiltIn
    }
}

/// An action paired with the offset at which it should run, measured from the
/// start of the macro. Produced by `MacroExpander`.
public struct ScheduledAction: Hashable, Sendable {
    public var action: MacroAction
    public var offset: TimeInterval

    public init(action: MacroAction, offset: TimeInterval) {
        self.action = action
        self.offset = offset
    }
}

/// Flattens nested macros into a flat, timed schedule.
///
/// `delay` actions are folded into the offsets rather than being handed to the
/// dispatcher, so the dispatcher never has to block a queue waiting on a sleep.
public enum MacroExpander {

    public enum ExpansionError: Error, CustomStringConvertible {
        case unknownMacro(id: String)
        case recursionLimitExceeded(id: String)

        public var description: String {
            switch self {
            case .unknownMacro(let id): return "Makro bulunamadı: \(id)"
            case .recursionLimitExceeded(let id): return "Makro döngüsü tespit edildi: \(id)"
            }
        }
    }

    /// Maximum nesting depth. Deep enough for real compositions, shallow enough
    /// that a cyclic reference is caught immediately instead of hanging.
    public static let maximumDepth = 8

    public static func expand(_ actions: [MacroAction],
                              macros: [String: Macro]) throws -> [ScheduledAction] {
        var output: [ScheduledAction] = []
        var cursor: TimeInterval = 0
        try expand(actions, macros: macros, depth: 0, cursor: &cursor, into: &output, visiting: [])
        return output
    }

    private static func expand(_ actions: [MacroAction],
                               macros: [String: Macro],
                               depth: Int,
                               cursor: inout TimeInterval,
                               into output: inout [ScheduledAction],
                               visiting: Set<String>) throws {
        for action in actions {
            switch action {
            case .delay(let seconds):
                cursor += max(seconds, 0)

            case .runMacro(let id):
                guard depth < maximumDepth, !visiting.contains(id) else {
                    throw ExpansionError.recursionLimitExceeded(id: id)
                }
                guard let macro = macros[id] else {
                    throw ExpansionError.unknownMacro(id: id)
                }
                try expand(macro.actions,
                           macros: macros,
                           depth: depth + 1,
                           cursor: &cursor,
                           into: &output,
                           visiting: visiting.union([id]))

            default:
                output.append(ScheduledAction(action: action, offset: cursor))
            }
        }
    }

    /// Total wall-clock duration of an expanded schedule.
    public static func duration(of schedule: [ScheduledAction]) -> TimeInterval {
        schedule.map(\.offset).max() ?? 0
    }
}
