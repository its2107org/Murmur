import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct MurmurWidgets: WidgetBundle {
    var body: some Widget {
        DictateWidget()
        DictationLiveActivity()
    }
}

private let accent = Color(red: 0.42, green: 0.32, blue: 0.95)

// MARK: - Home Screen and Lock Screen button

struct DictateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MurmurDictate", provider: DictateProvider()) { _ in
            DictateWidgetView()
                .containerBackground(for: .widget) { accent.gradient }
                .widgetURL(URL(string: "murmur://dictate"))
        }
        .configurationDisplayName("Dictate")
        .description("Opens Murmur and starts listening.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct DictateProvider: TimelineProvider {
    struct Entry: TimelineEntry { let date: Date }

    func placeholder(in context: Context) -> Entry { Entry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

struct DictateWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "waveform")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityLabel("Dictate with Murmur")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading) {
                    Text("Murmur").font(.headline)
                    Text("Tap to dictate").font(.caption)
                }
            }
        default:
            VStack(alignment: .leading) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                Spacer()
                Text("Dictate")
                    .font(.headline)
                Text("Private, on this iPhone")
                    .font(.caption)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Dynamic Island and Lock Screen while listening

struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationActivityAttributes.self) { context in
            LockScreenActivityView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StageIcon(stage: context.state.stage)
                        .font(.title2)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.stage == .listening {
                        Text(timerInterval: context.state.startedAt...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                            .font(.headline)
                            .frame(maxWidth: 64)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(title(for: context.state.stage))
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        if !context.state.preview.isEmpty {
                            Text(context.state.preview)
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if context.state.stage == .listening {
                            Button(intent: StopDictationIntent()) {
                                Label("Stop", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(.red)
                        }
                    }
                }
            } compactLeading: {
                StageIcon(stage: context.state.stage)
            } compactTrailing: {
                if context.state.stage == .listening {
                    Text(timerInterval: context.state.startedAt...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .frame(maxWidth: 40)
                } else {
                    Text(shortTitle(for: context.state.stage))
                        .font(.caption2.weight(.semibold))
                }
            } minimal: {
                StageIcon(stage: context.state.stage)
            }
            .keylineTint(accent)
        }
    }
}

private struct LockScreenActivityView: View {
    let state: DictationActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            StageIcon(stage: state.stage)
                .font(.title)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title(for: state.stage)).font(.headline)
                    Spacer()
                    if state.stage == .listening {
                        Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                            .font(.subheadline)
                            .frame(maxWidth: 60, alignment: .trailing)
                    }
                }
                if !state.preview.isEmpty {
                    Text(state.preview)
                        .font(.subheadline)
                        .lineLimit(2)
                        .opacity(0.8)
                }
            }
            if state.stage == .listening {
                Button(intent: StopDictationIntent()) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(.red)
                .accessibilityLabel("Stop dictating")
            }
        }
        .foregroundStyle(.white)
    }
}

private struct StageIcon: View {
    let stage: DictationActivityAttributes.ContentState.Stage

    var body: some View {
        switch stage {
        case .listening:
            Image(systemName: "waveform")
                .foregroundStyle(.red)
                .symbolEffect(.variableColor.iterative)
        case .tidying:
            Image(systemName: "wand.and.stars")
                .foregroundStyle(accent)
                .symbolEffect(.pulse)
        case .copied:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }
}

private func title(for stage: DictationActivityAttributes.ContentState.Stage) -> String {
    switch stage {
    case .listening: "Listening"
    case .tidying: "Tidying up"
    case .copied: "Copied, ready to paste"
    case .failed: "Murmur"
    }
}

private func shortTitle(for stage: DictationActivityAttributes.ContentState.Stage) -> String {
    switch stage {
    case .listening: ""
    case .tidying: "Tidying"
    case .copied: "Copied"
    case .failed: "Stopped"
    }
}
