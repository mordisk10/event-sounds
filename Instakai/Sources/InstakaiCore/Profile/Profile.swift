import Foundation

/// A complete, portable configuration: gestures, macros, tuning and calibration.
///
/// Profiles are the export/import unit. A user can share a JSON profile and
/// somebody else can load it without touching a line of code — that is the
/// "jeneratör" contract.
public struct Profile: Identifiable, Codable, Hashable, Sendable {

    /// Bumped whenever the on-disk shape changes; `ProfileStore` migrates.
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var notes: String

    /// Editable, form-shaped rules. These are the source of truth.
    public var blueprints: [RuleBlueprint]
    /// User macros plus copies of built-ins the user has modified.
    public var macros: [Macro]

    /// Named modes the profile supports. `Condition.mode` reads against the one
    /// currently selected in the session.
    public var modes: [String]
    public var defaultMode: String

    /// Initial values for user-defined flags.
    public var flags: [String: Bool]

    public var signalTuning: SignalTuning
    public var engineOptions: RuleEngine.Options
    public var calibration: [Signal: CalibrationRange]

    public init(id: UUID = UUID(),
                name: String,
                notes: String = "",
                blueprints: [RuleBlueprint] = [],
                macros: [Macro] = [],
                modes: [String] = ["varsayilan"],
                defaultMode: String = "varsayilan",
                flags: [String: Bool] = [:],
                signalTuning: SignalTuning = .default,
                engineOptions: RuleEngine.Options = .default,
                calibration: [Signal: CalibrationRange] = [:]) {
        self.schemaVersion = Profile.currentSchemaVersion
        self.id = id
        self.name = name
        self.notes = notes
        self.blueprints = blueprints
        self.macros = macros
        self.modes = modes
        self.defaultMode = defaultMode
        self.flags = flags
        self.signalTuning = signalTuning
        self.engineOptions = engineOptions
        self.calibration = calibration
    }

    /// Compiles the profile's blueprints into engine-ready rules.
    public var compiledRules: [Rule] {
        RuleGenerator.makeRules(from: blueprints)
    }

    /// Built-in macros plus the profile's own, with profile entries winning on
    /// id collisions so a user can override a built-in.
    public func resolvedMacros() -> [Macro] {
        var index = Dictionary(uniqueKeysWithValues: MacroLibrary.builtIns.map { ($0.id, $0) })
        for macro in macros { index[macro.id] = macro }
        return Array(index.values).sorted { $0.name < $1.name }
    }

    public var warnings: [RuleGenerator.Warning] {
        RuleGenerator.validate(blueprints: blueprints, macros: resolvedMacros())
    }
}

// MARK: - Codable for the calibration dictionary

extension Profile {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, notes, blueprints, macros, modes
        case defaultMode, flags, signalTuning, engineOptions, calibration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        blueprints = try container.decodeIfPresent([RuleBlueprint].self, forKey: .blueprints) ?? []
        macros = try container.decodeIfPresent([Macro].self, forKey: .macros) ?? []
        modes = try container.decodeIfPresent([String].self, forKey: .modes) ?? ["varsayilan"]
        defaultMode = try container.decodeIfPresent(String.self, forKey: .defaultMode) ?? "varsayilan"
        flags = try container.decodeIfPresent([String: Bool].self, forKey: .flags) ?? [:]
        signalTuning = try container.decodeIfPresent(SignalTuning.self, forKey: .signalTuning) ?? .default
        engineOptions = try container.decodeIfPresent(RuleEngine.Options.self, forKey: .engineOptions) ?? .default

        let rawCalibration = try container.decodeIfPresent([String: CalibrationRange].self,
                                                           forKey: .calibration) ?? [:]
        var mapped: [Signal: CalibrationRange] = [:]
        for (key, value) in rawCalibration {
            if let signal = Signal(rawValue: key) { mapped[signal] = value }
        }
        calibration = mapped
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(notes, forKey: .notes)
        try container.encode(blueprints, forKey: .blueprints)
        try container.encode(macros, forKey: .macros)
        try container.encode(modes, forKey: .modes)
        try container.encode(defaultMode, forKey: .defaultMode)
        try container.encode(flags, forKey: .flags)
        try container.encode(signalTuning, forKey: .signalTuning)
        try container.encode(engineOptions, forKey: .engineOptions)

        var rawCalibration: [String: CalibrationRange] = [:]
        for (signal, range) in calibration { rawCalibration[signal.rawValue] = range }
        try container.encode(rawCalibration, forKey: .calibration)
    }
}
