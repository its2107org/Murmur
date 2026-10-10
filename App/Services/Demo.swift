import Foundation

/// Sample content and self-checks for the automatic simulator run. Never used on a real iPhone.
enum Demo {
    static let arguments = ProcessInfo.processInfo.arguments

    static var isActive: Bool { arguments.contains { $0.hasPrefix("-MurmurDemo") || $0 == "-MurmurSelfTest" } }

    static let sample = Dictation(
        raw: "um hi Sarah so just following up on the um the Thursday call I think we should uh move the tasting to the 14th, no actually the 15th, and can you send over the updated deck. Format as email.",
        text: "Hi Sarah,\n\nJust following up on Thursday's call. I think we should move the tasting to the 15th. Could you send over the updated deck?\n\nThanks,",
        style: .email,
        tidied: true
    )

    @MainActor
    static func applyIfRequested() async {
        guard isActive else { return }
        Settings.hasSeenWelcome = true
        if arguments.contains("-MurmurSelfTest") { runSelfTest() }
        if arguments.contains("-MurmurDemoResult") {
            DictationController.shared.showForDemo(sample)
        }
        if arguments.contains("-MurmurDemoHistory") {
            Router.shared.section = .history
            if History.shared.items.isEmpty {
                History.shared.add(sample)
                History.shared.add(Dictation(raw: "", text: "• Milk\n• Eggs\n• Sourdough\n• Coffee beans", style: .bullets, tidied: true))
                History.shared.add(Dictation(raw: "", text: "Running ten minutes late, save me a seat.", style: .message, tidied: true))
            }
        }
        if arguments.contains("-MurmurDemoSettings") {
            Router.shared.section = .settings
        }
    }

    /// Checks the spoken-command and clean-up rules, and writes the results for the build log.
    @MainActor
    private static func runSelfTest() {
        let cases: [(String, String, String)] = [
            ("Hi John, see you Tuesday at three. Format this as an email.", "Hi John, see you Tuesday at three.", "Email"),
            ("Format as email. Hi John, running late.", "Hi John, running late.", "Email"),
            ("Let me know if you can make a list.", "Let me know if you can make a list.", "Tidied"),
            ("The meeting will be shorter.", "The meeting will be shorter.", "Tidied"),
            ("Milk, eggs, bread. Bullet points please.", "Milk, eggs, bread.", "Bullet points"),
            ("Okay, make it more formal. Hey Sarah, can't make it tonight.", "Hey Sarah, can't make it tonight.", "Formal"),
            ("I'll make it to the party tonight, see you there. Make it a text message.", "I'll make it to the party tonight, see you there.", "Message"),
            ("We discussed the deal and next steps. Turn this into meeting notes.", "We discussed the deal and next steps.", "Notes")
        ]
        var results: [[String: String]] = []
        var failures = 0
        for (input, text, label) in cases {
            let parsed = SpokenCommands.parse(input)
            let ok = parsed.text == text && parsed.style.label == label
            if !ok { failures += 1 }
            results.append(["input": input, "text": parsed.text, "style": parsed.style.label, "ok": ok ? "yes" : "NO"])
        }
        let cleaned = Tidier.basicClean("um so I think uh we should go. new paragraph Next point")
        let cleanOK = cleaned == "So I think we should go.\n\nNext point"
        if !cleanOK { failures += 1 }
        results.append(["input": "basic clean", "text": cleaned, "ok": cleanOK ? "yes" : "NO"])
        results.append(["summary": failures == 0 ? "all passed" : "\(failures) failed"])

        if let data = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL.documentsDirectory.appending(path: "selftest.json"))
        }
    }
}
