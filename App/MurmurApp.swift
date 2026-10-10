import SwiftUI

@main
struct MurmurApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { Router.shared.handle($0) }
                .task { await Demo.applyIfRequested() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { History.shared.load() }
        }
    }
}

/// Small bits of navigation state that intents and links can change.
@MainActor
@Observable
final class Router {
    static let shared = Router()

    var section: Section = .dictate
    var showMicrophoneHelp = false

    enum Section: Hashable { case dictate, history, settings }

    private init() {}

    /// murmur://dictate starts listening straight away (used by the keyboard and the widget).
    func handle(_ url: URL) {
        guard url.scheme == "murmur" else { return }
        switch url.host() {
        case "dictate":
            section = .dictate
            Task {
                do {
                    let controller = DictationController.shared
                    if controller.isListening { await controller.stop() } else { try await controller.start() }
                } catch LiveTranscriber.Problem.microphoneDenied {
                    showMicrophoneHelp = true
                } catch {}
            }
        case "history":
            section = .history
        default:
            break
        }
    }
}
