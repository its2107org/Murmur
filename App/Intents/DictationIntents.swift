import AppIntents
import Foundation

/// The Action Button shortcut: press once to start listening, press again to stop.
/// Murmur stays in the background; a recording indicator shows in the Dynamic Island.
struct ToggleDictationIntent: AudioRecordingIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Dictate"
    static let description = IntentDescription(
        "Starts listening without opening Murmur. Run it again to stop; your tidied text is copied, ready to paste."
    )
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        let controller = DictationController.shared
        if controller.isListening {
            await controller.stop()
            return .result()
        }
        if controller.isBusy { return .result() }

        do {
            try await controller.start()
        } catch LiveTranscriber.Problem.microphoneDenied {
            // Asking for the microphone (or explaining how to allow it) needs the app on screen.
            throw needsToContinueInForegroundError("Murmur needs your permission to use the microphone.") {
                Router.shared.showMicrophoneHelp = true
            }
        } catch {
            // If iOS won't let Murmur start the microphone from the background, open Murmur and start there.
            throw needsToContinueInForegroundError("Open Murmur to start dictating?") {
                try? await DictationController.shared.start()
            }
        }
        return .result()
    }
}

struct StartDictationIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Dictating"
    static let description = IntentDescription("Starts listening without opening Murmur.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await DictationController.shared.start()
        return .result()
    }
}

struct FinishDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish Dictating"
    static let description = IntentDescription("Stops listening, tidies what you said and gives back the text.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await DictationController.shared.stop()
        if case .finished(let item) = DictationController.shared.phase {
            return .result(value: item.text)
        }
        return .result(value: "")
    }
}

struct TidyTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Tidy Text"
    static let description = IntentDescription("Tidies some text on this device, optionally as an email, message or bullet points.")

    @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    @Parameter(title: "Style", default: .tidied)
    var style: StyleChoice

    static var parameterSummary: some ParameterSummary {
        Summary("Tidy \(\.$text) as \(\.$style)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let outcome = await Tidier.tidy(text, style: style.outputStyle, polish: Settings.polish)
        return .result(value: outcome.text)
    }
}

enum StyleChoice: String, AppEnum {
    case tidied, email, message, bullets, notes, shorter, formal, casual

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Style"
    static let caseDisplayRepresentations: [StyleChoice: DisplayRepresentation] = [
        .tidied: "Just tidied",
        .email: "Email",
        .message: "Text message",
        .bullets: "Bullet points",
        .notes: "Notes",
        .shorter: "Shorter",
        .formal: "More formal",
        .casual: "More casual"
    ]

    var outputStyle: OutputStyle {
        switch self {
        case .tidied: .plain
        case .email: .email
        case .message: .message
        case .bullets: .bullets
        case .notes: .notes
        case .shorter: .shorter
        case .formal: .formal
        case .casual: .casual
        }
    }
}

struct MurmurShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: [
                "Dictate with \(.applicationName)",
                "Start \(.applicationName)",
                "\(.applicationName) dictation"
            ],
            shortTitle: "Dictate",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: TidyTextIntent(),
            phrases: ["Tidy text with \(.applicationName)"],
            shortTitle: "Tidy Text",
            systemImageName: "wand.and.stars"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .purple
}
