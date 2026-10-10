import SwiftUI

struct SettingsView: View {
    @State private var tidyEnabled = Settings.tidyEnabled
    @State private var polish = Settings.polish
    @State private var copyToClipboard = Settings.copyToClipboard
    @State private var keepHistory = Settings.keepHistory
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let note = Tidier.availabilityNote {
                        Label(note, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    Toggle("Tidy up my words", isOn: $tidyEnabled)
                        .onChange(of: tidyEnabled) { _, v in Settings.tidyEnabled = v }
                    Picker("How much", selection: $polish) {
                        ForEach(Tidier.Polish.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!tidyEnabled)
                    .onChange(of: polish) { _, v in Settings.polish = v }
                } header: {
                    Text("Tidying")
                } footer: {
                    Text("Light takes out “ums”, repeats and false starts and fixes punctuation. Polished also smooths clumsy sentences. Both use Apple Intelligence on this iPhone.")
                }

                Section {
                    Toggle("Copy to clipboard", isOn: $copyToClipboard)
                        .onChange(of: copyToClipboard) { _, v in Settings.copyToClipboard = v }
                } header: {
                    Text("When you stop")
                } footer: {
                    Text("Ready to paste anywhere. If you're typing with the Murmur keyboard, the text goes straight in.")
                }

                Section("Spoken commands") {
                    CommandRow(say: "“Format as email”", does: "Greeting, paragraphs and sign-off")
                    CommandRow(say: "“Bullet points”", does: "A tidy list")
                    CommandRow(say: "“Make it a text message”", does: "Short and natural")
                    CommandRow(say: "“Turn this into notes”", does: "Grouped notes")
                    CommandRow(say: "“Make it shorter”", does: "Same facts, fewer words")
                    CommandRow(say: "“More formal” / “More casual”", does: "Changes the tone")
                    CommandRow(say: "“New paragraph”", does: "Starts a new paragraph")
                }

                Section("Set up") {
                    NavigationLink("Action Button") { ActionButtonGuide() }
                    NavigationLink("Murmur keyboard") { KeyboardGuide() }
                }

                Section {
                    Toggle("Keep history", isOn: $keepHistory)
                        .onChange(of: keepHistory) { _, v in Settings.keepHistory = v }
                    Button("Delete all history", role: .destructive) { confirmDelete = true }
                        .confirmationDialog("Delete every dictation?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete all", role: .destructive) {
                                History.shared.deleteAll()
                                Handoff.clearLatest()
                            }
                        }
                } header: {
                    Text("History")
                } footer: {
                    Text("History is kept only on this iPhone. Audio is never saved.")
                }

                Section("Privacy") {
                    PrivacyPoint(symbol: "iphone", text: "Speech is turned into text by Apple's speech engine on this iPhone.")
                    PrivacyPoint(symbol: "apple.intelligence", text: "Tidying uses the Apple Intelligence model that lives on this iPhone, not Apple's servers.")
                    PrivacyPoint(symbol: "wifi.slash", text: "Murmur contains no internet code at all, and no analytics. It works in Aeroplane Mode.")
                    PrivacyPoint(symbol: "waveform.slash", text: "Your voice recordings are never saved.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct CommandRow: View {
    let say: String
    let does: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(say).font(.body.weight(.medium))
            Text(does).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

private struct PrivacyPoint: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(.tint)
        }
    }
}
