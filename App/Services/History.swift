import Foundation
import Observation

struct Dictation: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var date = Date()
    /// Exactly what the iPhone heard, before any tidying.
    var raw: String
    var text: String
    var style: OutputStyle
    var tidied: Bool
    var note: String?
}

/// Past dictations, kept only in Murmur's own storage on this iPhone.
@MainActor
@Observable
final class History {
    static let shared = History()

    private(set) var items: [Dictation] = []
    private let limit = 300

    private var fileURL: URL {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "history.json")
    }

    private init() {
        load()
    }

    var isEnabled: Bool { Settings.keepHistory }

    func add(_ item: Dictation) {
        guard isEnabled else { return }
        items.insert(item, at: 0)
        if items.count > limit { items.removeLast(items.count - limit) }
        save()
    }

    func update(_ item: Dictation) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func delete(_ ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
        save()
    }

    func deleteAll() {
        items.removeAll()
        save()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([Dictation].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        // Readable after the phone is first unlocked, so Action Button dictations can be saved
        // while the app is in the background.
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

/// Ian's choices, kept on this iPhone.
enum Settings {
    private static let defaults = UserDefaults.standard

    static var keepHistory: Bool {
        get { defaults.object(forKey: "keepHistory") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "keepHistory") }
    }

    static var polish: Tidier.Polish {
        get { Tidier.Polish(rawValue: defaults.string(forKey: "polish") ?? "") ?? .light }
        set { defaults.set(newValue.rawValue, forKey: "polish") }
    }

    static var copyToClipboard: Bool {
        get { defaults.object(forKey: "copyToClipboard") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "copyToClipboard") }
    }

    static var tidyEnabled: Bool {
        get { defaults.object(forKey: "tidyEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "tidyEnabled") }
    }

    static var hasSeenWelcome: Bool {
        get { defaults.bool(forKey: "hasSeenWelcome") }
        set { defaults.set(newValue, forKey: "hasSeenWelcome") }
    }
}
