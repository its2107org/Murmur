import ActivityKit
import Foundation
import Observation
import UIKit

/// Runs one dictation from start to finish: listen, transcribe, tidy, then hand the text over.
@MainActor
@Observable
final class DictationController {
    static let shared = DictationController()

    enum Phase: Equatable {
        case idle
        case starting
        case listening
        case tidying
        case finished(Dictation)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var liveText = ""
    private(set) var level: Float = 0
    private(set) var startedAt = Date()

    private var transcriber: LiveTranscriber?
    private var activity: Activity<DictationActivityAttributes>?
    private var lastActivityUpdate = Date.distantPast
    private var safetyStop: Task<Void, Never>?

    /// Long enough for any normal dictation; stops a forgotten recording from running all day.
    private let maximumLength: TimeInterval = 20 * 60

    var isBusy: Bool {
        switch phase {
        case .starting, .listening, .tidying: true
        default: false
        }
    }

    var isListening: Bool { phase == .listening || phase == .starting }

    private init() {
        // The Murmur keyboard's Stop button.
        Handoff.observe(Handoff.stopNotification) {
            Task { await DictationController.shared.stop() }
        }
    }

    // MARK: - Start and stop

    func toggle() async throws {
        switch phase {
        case .listening, .starting: await stop()
        case .tidying: break
        default: try await start()
        }
    }

    func start() async throws {
        guard !isBusy else { return }
        phase = .starting
        liveText = ""
        startedAt = Date()
        Handoff.setPhase(.listening)
        // The Live Activity has to be showing before recording starts, or iOS stops the recording.
        startActivity()

        let transcriber = LiveTranscriber()
        transcriber.onUpdate = { [weak self] text in self?.heard(text) }
        transcriber.onLevel = { value in
            Task { @MainActor in DictationController.shared.level = value }
        }
        self.transcriber = transcriber

        do {
            try await transcriber.start()
        } catch {
            self.transcriber = nil
            Handoff.setPhase(.idle)
            await endActivity(stage: .failed, preview: "Couldn't start listening", after: 4)
            phase = .failed(error.localizedDescription)
            throw error
        }

        phase = .listening
        if Settings.tidyEnabled { Tidier.prewarm() }
        safetyStop = Task { [weak self, maximumLength] in
            try? await Task.sleep(for: .seconds(maximumLength))
            guard !Task.isCancelled else { return }
            await self?.stop()
        }
    }

    func stop() async {
        guard isListening, let transcriber else { return }
        safetyStop?.cancel()
        safetyStop = nil
        phase = .tidying
        level = 0
        Handoff.setPhase(.tidying)
        await updateActivity(stage: .tidying, preview: "Tidying up…")

        let raw = await transcriber.stop()
        self.transcriber = nil
        await finish(raw: raw)
    }

    func cancel() async {
        safetyStop?.cancel()
        safetyStop = nil
        await transcriber?.cancel()
        transcriber = nil
        phase = .idle
        level = 0
        Handoff.setPhase(.idle)
        await endActivity(stage: .failed, preview: "Cancelled", after: 0)
    }

    /// Used only for the simulator screenshots.
    func showForDemo(_ item: Dictation) {
        phase = .finished(item)
    }

    func dismissResult() {
        if !isBusy { phase = .idle }
    }

    // MARK: - Finishing

    private func finish(raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Handoff.setPhase(.idle)
            phase = .failed("Murmur didn't hear anything. Try again a little closer to the microphone.")
            await endActivity(stage: .failed, preview: "Didn't hear anything", after: 3)
            return
        }

        let parsed = SpokenCommands.parse(trimmed)
        let outcome: Tidier.Outcome
        if Settings.tidyEnabled {
            outcome = await Tidier.tidy(parsed.text, style: parsed.style, polish: Settings.polish)
        } else {
            outcome = Tidier.Outcome(text: Tidier.basicClean(parsed.text), usedModel: false, note: nil)
        }

        let item = Dictation(raw: trimmed, text: outcome.text, style: parsed.style,
                             tidied: outcome.usedModel, note: outcome.note)
        deliver(item)
        History.shared.add(item)
        phase = .finished(item)
        Handoff.setPhase(.idle)
        await endActivity(stage: .copied, preview: String(item.text.prefix(90)), after: 6)
    }

    /// Puts the text where Ian can use it: the clipboard, and the Murmur keyboard if it's open.
    private func deliver(_ item: Dictation) {
        if Settings.copyToClipboard {
            UIPasteboard.general.string = item.text
        }
        Handoff.publish(LatestResult(id: item.id, text: item.text, createdAt: item.date))
    }

    /// Tidies an older dictation again, for example one that was paused to save battery.
    func retidy(_ item: Dictation, as style: OutputStyle? = nil) async -> Dictation {
        let parsed = SpokenCommands.parse(item.raw)
        let outcome = await Tidier.tidy(parsed.text, style: style ?? parsed.style, polish: Settings.polish)
        var updated = item
        updated.text = outcome.text
        updated.style = style ?? parsed.style
        updated.tidied = outcome.usedModel
        updated.note = outcome.note
        History.shared.update(updated)
        if case .finished(let current) = phase, current.id == item.id { phase = .finished(updated) }
        return updated
    }

    private func heard(_ text: String) {
        liveText = text
        // The Dynamic Island only needs the odd refresh.
        guard Date().timeIntervalSince(lastActivityUpdate) > 1.5 else { return }
        lastActivityUpdate = Date()
        let tail = text.split(separator: " ").suffix(8).joined(separator: " ")
        Task { await updateActivity(stage: .listening, preview: tail) }
    }

    // MARK: - Live Activity

    private func startActivity() {
        Task { await endStaleActivities() }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = DictationActivityAttributes.ContentState(stage: .listening, startedAt: startedAt, preview: "")
        activity = try? Activity.request(
            attributes: DictationActivityAttributes(),
            content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(maximumLength + 60)),
            pushType: nil
        )
    }

    private func updateActivity(stage: DictationActivityAttributes.ContentState.Stage, preview: String) async {
        guard let activity else { return }
        let state = DictationActivityAttributes.ContentState(stage: stage, startedAt: startedAt, preview: preview)
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    private func endActivity(stage: DictationActivityAttributes.ContentState.Stage, preview: String,
                             after seconds: TimeInterval) async {
        guard let activity else { return }
        self.activity = nil
        let state = DictationActivityAttributes.ContentState(stage: stage, startedAt: startedAt, preview: preview)
        let policy: ActivityUIDismissalPolicy = seconds <= 0 ? .immediate : .after(Date().addingTimeInterval(seconds))
        await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy)
    }

    private func endStaleActivities() async {
        for old in Activity<DictationActivityAttributes>.activities where old.id != activity?.id {
            await old.end(nil, dismissalPolicy: .immediate)
        }
    }
}
