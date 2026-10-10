import SwiftUI

struct DictateView: View {
    @State private var controller = DictationController.shared
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.smooth, value: controller.phase)

                RecordButton(phase: controller.phase, level: controller.level) {
                    Task { await toggle() }
                }
                .padding(.bottom, 12)

                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 20)
            .navigationTitle("Murmur")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PrivacyBadge()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.phase {
        case .idle:
            EmptyPrompt()
        case .starting, .listening:
            LiveTranscript(text: controller.liveText, startedAt: controller.startedAt)
        case .tidying:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Tidying up…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        case .finished(let item):
            ScrollView {
                ResultCard(item: item)
                    .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        case .failed(let message):
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.bubble")
            } description: {
                Text(message)
            }
        }
    }

    private var hint: String {
        switch controller.phase {
        case .starting, .listening: "Tap to stop. Say “format as email” or “bullet points” at the end to shape it."
        case .tidying: "Tidying on this iPhone…"
        case .finished: Settings.copyToClipboard ? "Copied. Paste it anywhere." : "Ready to copy."
        default: "Tap to start, or press the Action Button from anywhere."
        }
    }

    private func toggle() async {
        do {
            try await controller.toggle()
        } catch LiveTranscriber.Problem.microphoneDenied {
            Router.shared.showMicrophoneHelp = true
        } catch {}
    }
}

// MARK: - Pieces

private struct EmptyPrompt: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, options: .repeat(.periodic(delay: 2)))
            Text("Speak naturally")
                .font(.title2.weight(.semibold))
            Text("Murmur writes it down, takes out the “ums” and tidies it up, all on this iPhone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 300)
        }
    }
}

private struct LiveTranscript: View {
    let text: String
    let startedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(.red).frame(width: 8, height: 8)
                    .symbolEffect(.pulse)
                Text("Listening")
                    .font(.subheadline.weight(.semibold))
                Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(text.isEmpty ? "Start talking…" : text)
                        .font(.title3)
                        .foregroundStyle(text.isEmpty ? .tertiary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("end")
                        .contentTransition(.opacity)
                }
                .onChange(of: text) { proxy.scrollTo("end", anchor: .bottom) }
            }
        }
        .padding(.top, 8)
    }
}

struct ResultCard: View {
    let item: Dictation
    @State private var copied = false
    @State private var working = false
    @State private var showOriginal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(item.style.label, systemImage: item.style.symbol)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.tint.opacity(0.12), in: Capsule())
                    .foregroundStyle(.tint)
                Spacer()
                ReshapeMenu(item: item, working: $working)
            }

            Text(showOriginal ? item.raw : item.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(working ? 0.4 : 1)
                .overlay { if working { ProgressView() } }

            if let note = item.note {
                Label(note, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = showOriginal ? item.raw : item.text
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .sensoryFeedback(.success, trigger: copied) { _, new in new }

                ShareLink(item: showOriginal ? item.raw : item.text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)

            Toggle("Show exactly what I said", isOn: $showOriginal)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ReshapeMenu: View {
    let item: Dictation
    @Binding var working: Bool

    private let choices: [OutputStyle] = [.plain, .email, .message, .bullets, .notes, .shorter, .formal, .casual]

    var body: some View {
        Menu {
            Section("Reshape as") {
                ForEach(choices.indices, id: \.self) { index in
                    let style = choices[index]
                    Button {
                        Task {
                            working = true
                            let updated = await DictationController.shared.retidy(item, as: style)
                            if Settings.copyToClipboard { UIPasteboard.general.string = updated.text }
                            working = false
                        }
                    } label: {
                        Label(style.label, systemImage: style.symbol)
                    }
                }
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.body.weight(.medium))
                .frame(width: 32, height: 32)
        }
        .disabled(working || !Tidier.isModelAvailable)
        .accessibilityLabel("Reshape")
    }
}

struct RecordButton: View {
    let phase: DictationController.Phase
    let level: Float
    let action: () -> Void

    private var listening: Bool { phase == .listening || phase == .starting }
    private var busy: Bool { phase == .tidying }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(listening ? 0.18 : 0))
                    .frame(width: 96, height: 96)
                    .scaleEffect(listening ? 1 + CGFloat(level) * 0.45 : 1)
                    .animation(.easeOut(duration: 0.12), value: level)
                Circle()
                    .fill(listening ? AnyShapeStyle(.red) : AnyShapeStyle(.tint))
                    .frame(width: 78, height: 78)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                Image(systemName: listening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 120, height: 120)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.5 : 1)
        .sensoryFeedback(.impact(weight: .medium), trigger: listening)
        .accessibilityLabel(listening ? "Stop dictating" : "Start dictating")
    }
}

struct PrivacyBadge: View {
    var body: some View {
        Label("On this iPhone", systemImage: "lock.fill")
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Everything stays on this iPhone")
    }
}
