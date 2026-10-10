import SwiftUI
import UIKit

/// The Murmur keyboard: a big microphone, plus the few keys needed around a dictation.
/// It never listens itself (iPhone keyboards aren't allowed the microphone); Murmur does the
/// listening in the background and hands the finished text back here.
final class KeyboardViewController: UIInputViewController {
    private let model = KeyboardModel()
    private var host: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        model.insert = { [weak self] text in self?.insert(text) }
        model.deleteBackward = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        model.returnKey = { [weak self] in self?.textDocumentProxy.insertText("\n") }
        model.space = { [weak self] in self?.textDocumentProxy.insertText(" ") }
        model.openMurmur = { [weak self] in self?.openMurmur() }
        model.nextKeyboard = { [weak self] in self?.advanceToNextInputMode() }

        let view = KeyboardView(model: model, controller: self)
        let host = UIHostingController(rootView: view)
        host.view.backgroundColor = .clear
        host.sizingOptions = [.intrinsicContentSize]
        addChild(host)
        self.view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
        let height = host.view.heightAnchor.constraint(equalToConstant: 260)
        height.priority = UILayoutPriority(999)
        height.isActive = true
        host.didMove(toParent: self)
        self.host = host
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.hasFullAccess = hasFullAccess
        model.showsGlobe = needsInputModeSwitchKey
        model.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        model.stop()
    }

    private func insert(_ text: String) {
        // Add a space if the text would otherwise run straight on from a word.
        if let before = textDocumentProxy.documentContextBeforeInput, let last = before.last,
           !last.isWhitespace, !text.hasPrefix("\n") {
            textDocumentProxy.insertText(" ")
        }
        textDocumentProxy.insertText(text)
    }

    /// Keyboards can't open apps directly, so this finds the app object the way other dictation
    /// keyboards do and asks it to open Murmur.
    private func openMurmur() {
        guard let url = URL(string: "murmur://dictate") else { return }
        var responder: UIResponder? = self
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        while let current = responder {
            if current.responds(to: selector), current is UIApplication {
                typealias OpenURL = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
                let method = current.method(for: selector)
                let open = unsafeBitCast(method, to: OpenURL.self)
                open(current, selector, url as NSURL, NSDictionary(), nil)
                return
            }
            responder = current.next
        }
    }
}

@MainActor
@Observable
final class KeyboardModel {
    var phase: DictationPhase = .idle
    var hasFullAccess = true
    var showsGlobe = true
    var lastInserted: UUID?
    var latestPreview: String?

    var insert: ((String) -> Void)?
    var deleteBackward: (() -> Void)?
    var returnKey: (() -> Void)?
    var space: (() -> Void)?
    var openMurmur: (() -> Void)?
    var nextKeyboard: (() -> Void)?

    private var timer: Timer?
    private var shownAt = Date()
    private var observing = false

    func start() {
        shownAt = Date()
        // Anything finished before the keyboard appeared isn't dropped in automatically, only offered.
        lastInserted = Handoff.latest?.id
        refresh()
        if !observing {
            observing = true
            Handoff.observe(Handoff.changedNotification) { [weak self] in self?.refresh() }
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        phase = Handoff.status.phase
        guard let latest = Handoff.latest else {
            latestPreview = nil
            return
        }
        latestPreview = latest.text
        if latest.id != lastInserted, latest.createdAt >= shownAt.addingTimeInterval(-2) {
            lastInserted = latest.id
            insert?(latest.text)
        }
    }

    func micTapped() {
        switch phase {
        case .listening: Handoff.requestStop()
        case .tidying: break
        case .idle: openMurmur?()
        }
    }

    func insertLatest() {
        guard let latest = Handoff.latest else { return }
        lastInserted = latest.id
        insert?(latest.text)
    }
}
