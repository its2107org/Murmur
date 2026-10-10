import Foundation

/// What Murmur is doing right now, shared so the keyboard can show it.
enum DictationPhase: String, Codable, Sendable {
    case idle, listening, tidying
}

struct DictationStatus: Codable, Sendable {
    var phase: DictationPhase
    var updatedAt: Date

    static let idle = DictationStatus(phase: .idle, updatedAt: .distantPast)

    /// A status left behind by a crash shouldn't make the keyboard look busy for ever.
    var isCurrent: Bool { Date().timeIntervalSince(updatedAt) < 15 * 60 }
}

/// The most recent finished dictation, handed from the app to the keyboard.
struct LatestResult: Codable, Sendable, Equatable {
    var id: UUID
    var text: String
    var createdAt: Date
}

/// Passes small bits of state between the app and the keyboard through the shared keychain,
/// with a nudge (a "Darwin notification", which carries no data) so the other side looks straight away.
enum Handoff {
    private static let service = "murmur.handoff"
    static let changedNotification = "murmur.handoff.changed"
    /// Sent by the keyboard's Stop button to the app, which keeps running in the background while it listens.
    static let stopNotification = "murmur.command.stop"

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static var status: DictationStatus {
        guard let data = SharedVault.read(service: service, account: "status"),
              let status = try? decoder.decode(DictationStatus.self, from: data),
              status.isCurrent else { return .idle }
        return status
    }

    static func setPhase(_ phase: DictationPhase) {
        let status = DictationStatus(phase: phase, updatedAt: Date())
        if let data = try? encoder.encode(status) {
            SharedVault.write(data, service: service, account: "status")
        }
        post()
    }

    static var latest: LatestResult? {
        guard let data = SharedVault.read(service: service, account: "latest") else { return nil }
        return try? decoder.decode(LatestResult.self, from: data)
    }

    static func publish(_ result: LatestResult) {
        if let data = try? encoder.encode(result) {
            SharedVault.write(data, service: service, account: "latest")
        }
        post()
    }

    static func clearLatest() {
        SharedVault.delete(service: service, account: "latest")
        post()
    }

    static func requestStop() {
        post(stopNotification)
    }

    private static func post(_ name: String = changedNotification) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }

    /// Calls `handler` on the main thread whenever the named nudge arrives.
    static func observe(_ name: String, handler: @escaping @MainActor () -> Void) {
        let box = Unmanaged.passRetained(HandlerBox(handler)).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), box,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let box = Unmanaged<HandlerBox>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { MainActor.assumeIsolated { box.handler() } }
            },
            name as CFString, nil, .deliverImmediately
        )
    }

    private final class HandlerBox: @unchecked Sendable {
        let handler: @MainActor () -> Void
        init(_ handler: @escaping @MainActor () -> Void) { self.handler = handler }
    }
}
