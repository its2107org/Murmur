import ActivityKit
import AppIntents
import Foundation

/// The little "Murmur is listening" display in the Dynamic Island and on the Lock Screen.
struct DictationActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Stage: String, Codable, Hashable {
            case listening, tidying, copied, failed
        }

        var stage: Stage
        var startedAt: Date
        /// The last few words heard, or the start of the finished text.
        var preview: String
    }
}

/// The Stop button in the Dynamic Island. Live Activity buttons always run inside the app itself,
/// so the widget's copy of this intent never does any work.
struct StopDictationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Dictating"
    static let description = IntentDescription("Stops listening and tidies up what you said.")
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if MURMUR_APP
        await DictationController.shared.stop()
        #endif
        return .result()
    }
}
