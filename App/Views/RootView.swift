import SwiftUI

struct RootView: View {
    @State private var router = Router.shared
    @State private var showWelcome = !Settings.hasSeenWelcome

    var body: some View {
        TabView(selection: $router.section) {
            Tab("Dictate", systemImage: "waveform", value: Router.Section.dictate) {
                DictateView()
            }
            Tab("History", systemImage: "clock", value: Router.Section.history) {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape", value: Router.Section.settings) {
                SettingsView()
            }
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeView { showWelcome = false }
                .interactiveDismissDisabled()
        }
        .alert("Microphone is switched off", isPresented: $router.showMicrophoneHelp) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Murmur needs the microphone to hear you. In Settings, switch on Microphone. Your voice is turned into text on this iPhone and never leaves it.")
        }
    }
}
