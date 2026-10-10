import Foundation

/// The shape Ian asked for out loud, such as "format as email".
enum OutputStyle: Equatable, Codable, Sendable {
    case plain
    case email
    case message
    case bullets
    case notes
    case shorter
    case formal
    case casual
    case custom(String)

    var label: String {
        switch self {
        case .plain: "Tidied"
        case .email: "Email"
        case .message: "Message"
        case .bullets: "Bullet points"
        case .notes: "Notes"
        case .shorter: "Shorter"
        case .formal: "Formal"
        case .casual: "Casual"
        case .custom(let what): what.prefix(1).uppercased() + what.dropFirst()
        }
    }

    var symbol: String {
        switch self {
        case .plain: "text.alignleft"
        case .email: "envelope"
        case .message: "message"
        case .bullets: "list.bullet"
        case .notes: "note.text"
        case .shorter: "arrow.down.right.and.arrow.up.left"
        case .formal: "briefcase"
        case .casual: "face.smiling"
        case .custom: "wand.and.stars"
        }
    }

    /// What the on-device model is told to do on top of the normal tidy-up.
    var instruction: String? {
        switch self {
        case .plain:
            nil
        case .email:
            "Lay it out as an email: a greeting line (use the recipient's name if the speaker gave one), short paragraphs, and a sign-off such as \"Best,\" or \"Thanks,\" on its own line. Do not invent a subject line, names or details. Leave the sign-off name blank unless the speaker said it."
        case .message:
            "Make it a short, natural text message. One or two short paragraphs at most, no greeting or sign-off unless the speaker said one."
        case .bullets:
            "Turn it into a list of short bullet points, one idea per line, each starting with \"• \". No heading."
        case .notes:
            "Turn it into tidy notes: a few short lines or bullet points starting with \"• \", grouping related points, keeping every fact, name, number and action."
        case .shorter:
            "Make it noticeably shorter and more concise while keeping every fact, name, number and request."
        case .formal:
            "Make the tone polished and professional, suitable for work, without making it longer."
        case .casual:
            "Make the tone relaxed and friendly, without making it longer."
        case .custom(let what):
            "Format it as \(what)."
        }
    }

    /// Styles that reshape the whole text, so it has to be handled in one go.
    var needsWholeText: Bool {
        switch self {
        case .plain, .formal, .casual: false
        default: true
        }
    }
}

/// Finds a formatting cue at the start or end of a dictation ("format this as an email",
/// "…bullet points please") and removes it from the text.
enum SpokenCommands {
    struct Parsed: Equatable {
        var text: String
        var style: OutputStyle
    }

    private static let lead = #"(?:(?:ok(?:ay)?|right|so|and|murmur|hey murmur)[,.]?\s+)?(?:(?:can|could) you\s+|please\s+)?"#
    private static let tail = #"(?:\s+please)?[\s.,!?]*"#
    private static let verbs = #"(?:format|write|make|turn|put|lay|set|do|send|convert|change|rewrite|reformat)(?:\s+(?:this|that|it|all of (?:this|that|it)|the (?:whole )?(?:thing|text|message|above)))?(?:\s+(?:out|up))?(?:\s+(?:as|into|in|to|like))?"#
    private static let article = #"(?:\s+(?:an?|the|some|my))?"#

    /// Short cues that work on their own, without a verb ("bullet points", "shorter").
    private static let bareCues: [(String, OutputStyle)] = [
        (#"(?:as |in )?bullet(?:ed)?(?: points?| list)?|as a list|in a list"#, .bullets),
        (#"as (?:an? )?e-?mail"#, .email),
        (#"as (?:a )?(?:text(?: message)?|message|whatsapp|slack message|imessage)"#, .message),
        (#"as notes|as meeting notes"#, .notes),
        (#"(?:make it |a bit |much )?(?:shorter|more concise)"#, .shorter),
        (#"(?:make it |a bit )?more (?:formal|professional)"#, .formal),
        (#"(?:make it |a bit )?more (?:casual|friendly|relaxed)"#, .casual)
    ]

    static func parse(_ raw: String) -> Parsed {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return Parsed(text: "", style: .plain) }

        // Look at the end first: people usually say what they want after they've said it.
        if let found = match(in: text, atEnd: true) { return found }
        if let found = match(in: text, atEnd: false) { return found }
        return Parsed(text: text, style: .plain)
    }

    private static func match(in text: String, atEnd: Bool) -> Parsed? {
        let withVerb = lead + verbs + article + #"\s+([a-z][a-z \-']{1,40}?)"# + tail
        let candidates: [(String, Bool)] = [(withVerb, true)] + bareCues.map { (lead + "(?:" + $0.0 + ")" + tail, false) }

        for (index, (pattern, hasObject)) in candidates.enumerated() {
            // Only trust a cue that is its own sentence, so "it'll be shorter" isn't taken as one.
            let anchored = atEnd
                ? #"(?:^|[.,!?:;]\s*)"# + "(" + pattern + ")$"
                : "^(" + pattern + #")[.,:;!?]\s*"#
            guard let regex = try? NSRegularExpression(pattern: anchored, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let m = regex.firstMatch(in: text, range: range),
                  let whole = Range(m.range(at: 1), in: text) else { continue }

            let found: OutputStyle
            if hasObject {
                guard let objectRange = Range(m.range(at: 2), in: text),
                      let parsed = style(for: String(text[objectRange])) else { continue }
                found = parsed
            } else {
                found = bareCues[index - 1].1
            }

            var rest = text
            guard let full = Range(m.range, in: text) else { continue }
            rest.removeSubrange(atEnd ? whole.lowerBound..<text.endIndex : text.startIndex..<full.upperBound)
            rest = rest.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
            // A cue with nothing else said isn't a cue.
            guard rest.split(separator: " ").count >= 2 else { continue }
            return Parsed(text: rest, style: found)
        }
        return nil
    }

    /// Works out the style from what followed "format it as…".
    static func style(for object: String) -> OutputStyle? {
        let o = object.lowercased().trimmingCharacters(in: .whitespaces)
        func has(_ words: String...) -> Bool { words.contains { o.contains($0) } }

        if has("email", "e-mail") { return .email }
        if has("bullet", "list") { return .bullets }
        if has("text", "message", "whatsapp", "slack", "imessage", "sms") { return .message }
        if has("note", "minutes", "summary") { return .notes }
        if has("shorter", "concise", "brief") { return .shorter }
        if has("formal", "professional") { return .formal }
        if has("casual", "friendly", "relaxed", "informal") { return .casual }

        // "Make it…" and "do…" are too common in normal speech to trust with anything else.
        let known = ["paragraph", "letter", "memo", "tweet", "post", "linkedin", "agenda", "to-do", "todo", "checklist", "table", "headline", "title", "outline", "haiku", "poem", "proposal", "update", "report", "invitation"]
        if let word = known.first(where: { o.contains($0) }) {
            if word == "to-do" || word == "todo" || word == "checklist" { return .bullets }
            return .custom(o.hasPrefix("a ") || o.hasPrefix("an ") ? o : "a " + o)
        }
        return nil
    }
}
