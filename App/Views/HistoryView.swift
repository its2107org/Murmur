import SwiftUI

struct HistoryView: View {
    @State private var history = History.shared
    @State private var search = ""

    private var filtered: [Dictation] {
        guard !search.isEmpty else { return history.items }
        return history.items.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(String, [Dictation])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            let title: String
            if calendar.isDateInToday(day) { title = "Today" }
            else if calendar.isDateInYesterday(day) { title = "Yesterday" }
            else { title = day.formatted(.dateTime.weekday(.wide).day().month(.wide)) }
            return (title, groups[day] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.items.isEmpty {
                    ContentUnavailableView {
                        Label(Settings.keepHistory ? "Nothing yet" : "History is off",
                              systemImage: "clock")
                    } description: {
                        Text(Settings.keepHistory
                             ? "Your dictations will appear here. They're kept only on this iPhone."
                             : "Switch history on in Settings to keep your dictations on this iPhone.")
                    }
                } else {
                    List {
                        ForEach(grouped, id: \.0) { title, items in
                            Section(title) {
                                ForEach(items) { item in
                                    NavigationLink(value: item.id) {
                                        HistoryRow(item: item)
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            UIPasteboard.general.string = item.text
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                        .tint(.accentColor)
                                    }
                                }
                                .onDelete { offsets in
                                    history.delete(Set(offsets.map { items[$0].id }))
                                }
                            }
                        }
                    }
                    .searchable(text: $search)
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { id in
                if let item = history.items.first(where: { $0.id == id }) {
                    HistoryDetail(item: item)
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let item: Dictation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.text)
                .lineLimit(2)
            HStack(spacing: 6) {
                Image(systemName: item.style.symbol)
                Text(item.date, style: .time)
                if !item.tidied {
                    Text("· not tidied")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct HistoryDetail: View {
    let item: Dictation

    var body: some View {
        ScrollView {
            ResultCard(item: item)
                .padding()
        }
        .navigationTitle(item.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
