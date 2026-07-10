import SwiftUI
import AVFoundation

// MARK: - History tab

/// Wispr Flow-style browser over the pipeline history: search, date-grouped list,
/// raw-vs-cleaned comparison, playback and re-transcription of the retained audio.
struct DashboardHistoryTab: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var expandedIDs: Set<UUID> = []
    @State private var displayLimit = 50
    @State private var confirmingClearAll = false
    @StateObject private var player = HistoryAudioPlayer()

    private var filteredItems: [PipelineHistoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.pipelineHistory }
        return appState.pipelineHistory.filter { item in
            item.rawTranscript.localizedCaseInsensitiveContains(query)
                || item.postProcessedTranscript.localizedCaseInsensitiveContains(query)
                || (item.contextAppName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var visibleItems: [PipelineHistoryItem] {
        Array(filteredItems.prefix(displayLimit))
    }

    private var dayGroups: [(title: String, items: [PipelineHistoryItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleItems) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.keys.sorted(by: >).map { day in
            (Self.dayTitle(for: day, calendar: calendar), grouped[day] ?? [])
        }
    }

    private static func dayTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: day)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if appState.pipelineHistory.isEmpty {
                emptyState(icon: "clock.arrow.circlepath", text: "Dictations you make will show up here.")
            } else if filteredItems.isEmpty {
                emptyState(icon: "magnifyingglass", text: "No dictations match \u{201C}\(searchText)\u{201D}")
            } else {
                historyList
            }
        }
        .alert("Clear all history?", isPresented: $confirmingClearAll) {
            Button("Clear All", role: .destructive) { appState.clearAllHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every dictation record and its retained audio. This cannot be undone.")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search dictations…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))

            Text("\(filteredItems.count) dictation\(filteredItems.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                confirmingClearAll = true
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .controlSize(.small)
            .disabled(appState.pipelineHistory.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8, pinnedViews: [.sectionHeaders]) {
                ForEach(dayGroups, id: \.title) { group in
                    Section {
                        ForEach(group.items) { item in
                            HistoryRow(
                                item: item,
                                isExpanded: expandedIDs.contains(item.id),
                                player: player,
                                onToggle: { toggle(item.id) }
                            )
                        }
                    } header: {
                        Text(group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(Color(NSColor.windowBackgroundColor))
                    }
                }
                if filteredItems.count > displayLimit {
                    Button("Show older dictations") { displayLimit += 50 }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggle(_ id: UUID) {
        if expandedIDs.contains(id) { expandedIDs.remove(id) } else { expandedIDs.insert(id) }
    }
}

// MARK: - Row

private struct HistoryRow: View {
    @EnvironmentObject var appState: AppState
    let item: PipelineHistoryItem
    let isExpanded: Bool
    @ObservedObject var player: HistoryAudioPlayer
    let onToggle: () -> Void
    @State private var isHovering = false

    private var displayText: String {
        item.postProcessedTranscript.isEmpty ? item.rawTranscript : item.postProcessedTranscript
    }

    private var audioURL: URL? {
        guard let name = item.audioFileName else { return nil }
        let url = AppState.audioStorageDirectory().appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var timeLabel: String {
        item.timestamp.formatted(date: .omitted, time: .shortened)
    }

    /// True when the cleanup step errored or fell back to the raw transcript —
    /// these are the entries worth re-transcribing.
    private var isFailure: Bool {
        let status = item.postProcessingStatus
        return status.hasPrefix("Error:") || status.localizedCaseInsensitiveContains("failed")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsedRow
            if isExpanded { expandedDetail }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(isHovering || isExpanded ? 1 : 0.55))
        )
        .onHover { isHovering = $0 }
    }

    private var collapsedRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(timeLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayText)
                    .font(.callout)
                    .lineLimit(isExpanded ? nil : 2)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    if let app = item.contextAppName, !app.isEmpty {
                        Text(app)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(Color.accentColor)
                    }
                    if isFailure {
                        Label("Cleanup failed — pasted raw", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.red.opacity(0.12)))
                            .foregroundStyle(.red)
                            .help(item.postProcessingStatus)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovering && !isExpanded {
                copyButton(text: displayText, help: "Copy")
            }

            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.vertical, 6)

            if item.rawTranscript != item.postProcessedTranscript && !item.postProcessedTranscript.isEmpty {
                transcriptBubble(title: "Heard", text: item.rawTranscript, tint: .secondary)
                transcriptBubble(title: "Cleaned", text: item.postProcessedTranscript, tint: Color.accentColor)
            } else {
                transcriptBubble(title: "Transcript", text: displayText, tint: Color.accentColor)
                Text("No cleanup changes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                if let audioURL {
                    Button {
                        player.toggle(url: audioURL, itemID: item.id)
                    } label: {
                        Label(
                            player.playingItemID == item.id ? "Stop" : "Play",
                            systemImage: player.playingItemID == item.id ? "stop.fill" : "play.fill"
                        )
                    }
                    .controlSize(.small)

                    if appState.retryingItemIDs.contains(item.id) {
                        ProgressView().controlSize(.small)
                    } else {
                        Button {
                            appState.retryTranscription(item: item)
                        } label: {
                            Label("Re-transcribe", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .help("Run this recording through transcription and cleanup again")
                    }
                }

                copyButton(text: displayText, help: "Copy cleaned text")

                Spacer()

                Button(role: .destructive) {
                    if player.playingItemID == item.id { player.stop() }
                    appState.deleteHistoryEntry(id: item.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .controlSize(.small)
            }
        }
    }

    private func transcriptBubble(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.08)))
        }
    }

    private func copyButton(text: String, help: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}

// MARK: - Audio playback

final class HistoryAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingItemID: UUID?
    private var player: AVAudioPlayer?

    func toggle(url: URL, itemID: UUID) {
        if playingItemID == itemID {
            stop()
            return
        }
        stop()
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        newPlayer.delegate = self
        player = newPlayer
        playingItemID = itemID
        newPlayer.play()
    }

    func stop() {
        player?.stop()
        player = nil
        playingItemID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.playingItemID = nil
            self?.player = nil
        }
    }
}
