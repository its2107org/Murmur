import SwiftUI

struct WelcomeView: View {
    var onDone: () -> Void

    @State private var preparing = false
    @State private var ready = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "waveform")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(.tint)
                        Text("Welcome to Murmur")
                            .font(.largeTitle.bold())
                        Text("Talk, and get clean, tidy text you can paste anywhere. Everything happens on this iPhone. Nothing you say is ever sent anywhere.")
                            .foregroundStyle(.secondary)
                    }

                    GuideStep(number: 1, title: "Let Murmur hear you",
                              detail: "Tap the button below. Your iPhone will ask to use the microphone; tap Allow. It also downloads Apple's English speech files once, if they aren't on your phone yet. Only the files come down; nothing you say goes up.")

                    if ready {
                        Label("All set", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await prepare() }
                        } label: {
                            HStack {
                                if preparing { ProgressView().tint(.white) }
                                Text(preparing ? "Getting ready…" : "Allow microphone")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(preparing)
                    }

                    if let problem {
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    GuideStep(number: 2, title: "Put it on your Action Button",
                              detail: "Then one press starts listening from anywhere, without opening Murmur. Press again to stop, and your tidied text is copied, ready to paste. Steps are in Settings › Action Button.")

                    GuideStep(number: 3, title: "Add the Murmur keyboard (optional)",
                              detail: "With it, your words drop straight into whatever you're typing. Steps are in Settings › Murmur keyboard.")
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Settings.hasSeenWelcome = true
                    onDone()
                } label: {
                    Text(ready ? "Start" : "Skip for now").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(24)
                .background(.bar)
            }
        }
    }

    private func prepare() async {
        preparing = true
        defer { preparing = false }
        problem = nil
        guard await LiveTranscriber.requestMicrophone() else {
            problem = "The microphone is switched off for Murmur. Open the Settings app, scroll down and tap Murmur, then switch on Microphone."
            return
        }
        do {
            try await LiveTranscriber.prepareSpeechFiles()
            ready = true
        } catch {
            problem = "Apple's speech files couldn't download right now. Murmur will try again the first time you dictate. (\(error.localizedDescription))"
            ready = true
        }
    }
}

struct ActionButtonGuide: View {
    var body: some View {
        List {
            Section {
                GuideStep(number: 1, title: "Open the Settings app",
                          detail: "It's the grey icon with cogs on your Home Screen.")
                GuideStep(number: 2, title: "Tap “Action Button”",
                          detail: "Scroll down a little. It's in the list with a small blue icon of a button.")
                GuideStep(number: 3, title: "Swipe to “Shortcut”",
                          detail: "At the top is a picture of your iPhone's side. Swipe left or right across it until the name under it says Shortcut.")
                GuideStep(number: 4, title: "Tap “Choose a Shortcut…”",
                          detail: "It's the blue button just under the picture.")
                GuideStep(number: 5, title: "Pick Murmur, then “Dictate”",
                          detail: "Type Murmur in the search box at the top, or scroll to Murmur's purple tiles. Tap the one called Dictate. You'll go back to the Action Button screen with Dictate chosen.")
            } footer: {
                Text("Now press and hold the Action Button on the left side of your iPhone (the small button above the volume buttons) until it starts. Talk, then press and hold again to stop. Your text is copied, ready to paste.")
            }
        }
        .navigationTitle("Action Button")
    }
}

struct KeyboardGuide: View {
    var body: some View {
        List {
            Section {
                GuideStep(number: 1, title: "Open the Settings app",
                          detail: "The grey icon with cogs.")
                GuideStep(number: 2, title: "Tap General, then Keyboard",
                          detail: "General is near the top with a grey cog. Keyboard is about halfway down that page.")
                GuideStep(number: 3, title: "Tap Keyboards, then “Add New Keyboard…”",
                          detail: "Keyboards is the first row. “Add New Keyboard…” is in blue at the bottom of the list.")
                GuideStep(number: 4, title: "Tap Murmur",
                          detail: "It's under “Third-Party Keyboards”. You'll go back to the list, which now includes Murmur.")
                GuideStep(number: 5, title: "Tap Murmur again and switch on “Allow Full Access”",
                          detail: "iPhone shows a warning. Tap Allow. The keyboard needs this to receive the text from Murmur. Murmur has no internet code, so nothing can leave your phone.")
            }
            Section {
                GuideStep(number: 6, title: "Switch to it when typing",
                          detail: "In any text box, tap the globe key at the bottom left of the keyboard until you see Murmur's big microphone. Tap it to start. Murmur pops open to listen; tap the small “◀ back” label at the very top left of the screen to return, and keep talking. Tap Stop on the keyboard when done, and your text drops in.")
                GuideStep(number: 7, title: "Even quicker: use the Action Button",
                          detail: "With the Murmur keyboard showing, press the Action Button, talk, and press again. The text goes straight into the box without leaving the app.")
            }
        }
        .navigationTitle("Murmur keyboard")
    }
}

struct GuideStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.tint, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
