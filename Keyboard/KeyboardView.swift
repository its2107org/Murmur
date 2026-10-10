import SwiftUI
import UIKit

struct KeyboardView: View {
    @Bindable var model: KeyboardModel
    weak var controller: UIInputViewController?

    private let accent = Color(red: 0.42, green: 0.32, blue: 0.95)

    var body: some View {
        VStack(spacing: 10) {
            if !model.hasFullAccess {
                Text("To finish setting up, open Settings › General › Keyboard › Keyboards › Murmur and switch on Allow Full Access.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Spacer(minLength: 0)

            Button {
                model.micTapped()
            } label: {
                ZStack {
                    Circle()
                        .fill(model.phase == .listening ? Color.red : accent)
                        .frame(width: 84, height: 84)
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    if model.phase == .tidying {
                        ProgressView().tint(.white).controlSize(.large)
                    } else {
                        Image(systemName: model.phase == .listening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.hasFullAccess)
            .accessibilityLabel(model.phase == .listening ? "Stop dictating" : "Start dictating")

            Text(statusText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                if model.showsGlobe, let controller {
                    GlobeKey(controller: controller)
                        .frame(width: 44, height: 42)
                }
                KeyButton(systemImage: "doc.on.clipboard", label: "Insert last dictation") { model.insertLatest() }
                    .frame(width: 52)
                    .disabled(model.latestPreview == nil)
                KeyButton(title: "space") { model.space?() }
                RepeatingKey(systemImage: "delete.left", label: "Delete") { model.deleteBackward?() }
                    .frame(width: 52)
                KeyButton(systemImage: "return", label: "Return") { model.returnKey?() }
                    .frame(width: 52)
            }
            .frame(height: 42)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
    }

    private var statusText: String {
        switch model.phase {
        case .listening: "Listening… tap to stop"
        case .tidying: "Tidying up…"
        case .idle: "Tap to dictate, or press the Action Button"
        }
    }
}

private struct KeyButton: View {
    var title: String? = nil
    var systemImage: String? = nil
    var label: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let title { Text(title) } else if let systemImage { Image(systemName: systemImage) }
            }
            .font(.system(size: 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? title ?? "")
    }
}

/// Delete key that keeps deleting while held, like the normal keyboard.
private struct RepeatingKey: View {
    let systemImage: String
    let label: String
    let action: () -> Void
    @State private var timer: Timer?

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 30) {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                    MainActor.assumeIsolated { action() }
                }
            } onPressingChanged: { pressing in
                if pressing {
                    action()
                } else {
                    timer?.invalidate()
                    timer = nil
                }
            }
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

/// The globe key. Uses the system's own handler so a long press shows the keyboard list.
private struct GlobeKey: UIViewRepresentable {
    let controller: UIInputViewController

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 8
        button.layer.cornerCurve = .continuous
        button.accessibilityLabel = "Next keyboard"
        button.addTarget(controller, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
