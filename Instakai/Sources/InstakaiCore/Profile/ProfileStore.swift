import Foundation

/// Loads and saves profiles as JSON, with schema migration on read.
///
/// Deliberately filesystem-based rather than `UserDefaults`: profiles are meant
/// to be exported, shared and hand-edited, so they need to be real files.
public final class ProfileStore {

    public enum StoreError: Error, CustomStringConvertible {
        case unsupportedSchema(found: Int, supported: Int)
        case emptyLibrary

        public var description: String {
            switch self {
            case .unsupportedSchema(let found, let supported):
                return "Profil şeması \(found), bu sürüm en fazla \(supported) destekliyor."
            case .emptyLibrary:
                return "Kayıtlı profil yok."
            }
        }
    }

    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// The app's default location: `Documents/Profiles`.
    public static func makeDefault() throws -> ProfileStore {
        let documents = try FileManager.default.url(for: .documentDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil,
                                                    create: true)
        return try ProfileStore(directory: documents.appendingPathComponent("Profiles", isDirectory: true))
    }

    // MARK: - Encoding

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func encode(_ profile: Profile) throws -> Data {
        try makeEncoder().encode(profile)
    }

    public static func decode(_ data: Data) throws -> Profile {
        let profile = try JSONDecoder().decode(Profile.self, from: data)
        return try migrate(profile)
    }

    /// Applies forward migrations. Only version 1 exists today; the switch is
    /// here so the next bump has an obvious home and old files keep loading.
    static func migrate(_ profile: Profile) throws -> Profile {
        var migrated = profile
        switch profile.schemaVersion {
        case Profile.currentSchemaVersion:
            return migrated
        case ..<Profile.currentSchemaVersion:
            migrated.schemaVersion = Profile.currentSchemaVersion
            return migrated
        default:
            throw StoreError.unsupportedSchema(found: profile.schemaVersion,
                                               supported: Profile.currentSchemaVersion)
        }
    }

    // MARK: - Filesystem

    private func url(for profile: Profile) -> URL {
        directory.appendingPathComponent("\(profile.id.uuidString).json")
    }

    public func save(_ profile: Profile) throws {
        try ProfileStore.encode(profile).write(to: url(for: profile), options: .atomic)
    }

    public func delete(_ profile: Profile) throws {
        let target = url(for: profile)
        guard fileManager.fileExists(atPath: target.path) else { return }
        try fileManager.removeItem(at: target)
    }

    public func loadAll() throws -> [Profile] {
        let contents = try fileManager.contentsOfDirectory(at: directory,
                                                           includingPropertiesForKeys: nil)
        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { try? ProfileStore.decode(Data(contentsOf: $0)) }
            .sorted { $0.name < $1.name }
    }

    /// Loads the library, seeding it with the built-in presets on first launch
    /// so the app is never in a state with nothing to run.
    public func loadOrSeed() throws -> [Profile] {
        let existing = try loadAll()
        guard existing.isEmpty else { return existing }
        let seeded = PresetLibrary.all
        for profile in seeded { try save(profile) }
        return seeded
    }

    // MARK: - Import / export

    public func exportJSON(_ profile: Profile) throws -> String {
        String(decoding: try ProfileStore.encode(profile), as: UTF8.self)
    }

    /// Imports a profile from JSON, assigning a fresh id so importing your own
    /// export never silently overwrites the original.
    public func importJSON(_ json: String) throws -> Profile {
        var profile = try ProfileStore.decode(Data(json.utf8))
        profile.id = UUID()
        profile.name += " (içe aktarıldı)"
        try save(profile)
        return profile
    }
}
