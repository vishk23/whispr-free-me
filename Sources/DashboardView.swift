import SwiftUI
import Charts

// MARK: - Dashboard tab enum

enum DashboardTab: String, CaseIterable, Identifiable {
    case stats       = "Stats"
    case dictionary  = "Dictionary"
    case snippets    = "Snippets"
    case voiceClone  = "Voice Clone"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stats:       return "chart.bar.fill"
        case .dictionary:  return "text.book.closed.fill"
        case .snippets:    return "text.badge.plus"
        case .voiceClone:  return "waveform.badge.plus"
        }
    }
}

// MARK: - Root view

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: DashboardTab = .stats

    private var metrics: DashboardMetrics {
        DashboardMetrics.compute(
            history: appState.pipelineHistory,
            voiceBankStats: appState.voiceBankStats(),
            voiceBankSamples: appState.voiceBankSamples()
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Persistent header ──
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Voice")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Dictation activity and voice bank stats")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // ── Tab switcher ──
            Picker("Tab", selection: $selectedTab) {
                ForEach(DashboardTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            // ── Tab content ──
            Group {
                switch selectedTab {
                case .stats:
                    DashboardStatsTab(metrics: metrics)
                case .dictionary:
                    DashboardDictionaryTab()
                case .snippets:
                    DashboardSnippetsTab()
                case .voiceClone:
                    DashboardVoiceCloneTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Stats tab

private struct DashboardStatsTab: View {
    let metrics: DashboardMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statCardsSection
                insightRowSection
                activityChartSection
                topAppsSection
                voiceBankReadinessSection
            }
            .padding(24)
        }
    }

    // MARK: Stat cards

    private var statCardsSection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            StatCard(value: "\(metrics.totalDictations)", label: "Total dictations")
            StatCard(value: "\(metrics.totalWords)", label: "Total words")
            StatCard(value: formatTimeSaved(metrics.timeSavedMinutes), label: "Time saved")
            StatCard(value: metrics.currentStreakDays > 0 ? "\(metrics.currentStreakDays) 🔥" : "0", label: "Day streak")
            StatCard(value: metrics.avgSpeakingWPM > 0 ? "\(Int(metrics.avgSpeakingWPM))" : "—", label: "Avg speaking WPM")
            StatCard(value: String(format: "%.1f min", metrics.voiceBankMinutes), label: "Minutes banked")
        }
    }

    private func formatTimeSaved(_ minutes: Double) -> String {
        if minutes < 1 { return "< 1 min" }
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours == 0 { return "\(mins) min" }
        if mins == 0 { return "\(hours) hr" }
        return "\(hours) hr \(mins) min"
    }

    // MARK: Insight row

    private var insightRowSection: some View {
        HStack(spacing: 12) {
            // Avg words per dictation
            InsightCard(
                icon: "text.word.spacing",
                value: metrics.avgWordsPerDictation > 0
                    ? String(format: "%.0f", metrics.avgWordsPerDictation)
                    : "—",
                label: "Avg words / dictation"
            )

            // This week vs last week
            let delta = metrics.dictationsThisWeek - metrics.dictationsLastWeek
            let arrow: String = delta > 0 ? "↑" : (delta < 0 ? "↓" : "→")
            let deltaColor: Color = delta > 0 ? .green : (delta < 0 ? .red : .secondary)
            InsightCard(
                icon: "calendar.badge.clock",
                value: "\(metrics.dictationsThisWeek)",
                label: "This week",
                badge: delta != 0
                    ? "\(arrow) \(abs(delta)) vs last wk"
                    : (metrics.dictationsLastWeek == 0 ? "same as last wk" : "same as last wk"),
                badgeColor: deltaColor
            )

            // Busiest weekday
            InsightCard(
                icon: "star.fill",
                value: metrics.busiestWeekday ?? "—",
                label: "Busiest weekday"
            )
        }
    }

    // MARK: Activity chart

    private var activityChartSection: some View {
        let recent = Array(metrics.activityLast30Days.suffix(14))
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent activity")
                    .font(.headline)
                if recent.isEmpty || recent.allSatisfy({ $0.count == 0 }) {
                    Text("No dictations recorded yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                } else {
                    Chart(recent, id: \.date) { entry in
                        BarMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Dictations", entry.count)
                        )
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                        .font(.caption2)
                                }
                                AxisGridLine()
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            if let intVal = value.as(Int.self), intVal >= 0 {
                                AxisValueLabel { Text("\(intVal)").font(.caption2) }
                                AxisGridLine()
                            }
                        }
                    }
                    .frame(height: 120)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Top apps

    private var topAppsSection: some View {
        let apps = metrics.topApps
        guard !apps.isEmpty else { return AnyView(EmptyView()) }

        let maxCount = apps.map(\.count).max() ?? 1

        return AnyView(GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Top apps")
                    .font(.headline)
                VStack(spacing: 6) {
                    ForEach(apps, id: \.name) { app in
                        HStack(spacing: 8) {
                            Text(app.name)
                                .font(.subheadline)
                                .frame(width: 160, alignment: .leading)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 16)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.accentColor.opacity(0.7))
                                        .frame(
                                            width: max(4, geo.size.width * CGFloat(app.count) / CGFloat(maxCount)),
                                            height: 16
                                        )
                                }
                            }
                            .frame(height: 16)
                            Text("\(app.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        })
    }

    // MARK: Voice bank readiness

    private var voiceBankReadinessSection: some View {
        let minutes = metrics.voiceBankMinutes
        let instantCloneTarget = 3.0
        let proCloneTarget = 30.0

        return GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Voice bank readiness")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ReadinessRow(
                        label: "Instant clone",
                        detail: "~3 min needed",
                        progress: min(1.0, minutes / instantCloneTarget),
                        current: minutes,
                        target: instantCloneTarget
                    )
                    ReadinessRow(
                        label: "Pro clone",
                        detail: "~30 min needed",
                        progress: min(1.0, minutes / proCloneTarget),
                        current: minutes,
                        target: proCloneTarget
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Dictionary tab

struct DashboardDictionaryTab: View {
    @EnvironmentObject var appState: AppState
    @State private var newTerm: String = ""

    /// Split delimiter matches PostProcessingService.mergedVocabularyTerms — newline, comma, or semicolon.
    private var terms: [String] {
        appState.customVocabulary
            .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func joinTerms(_ list: [String]) -> String {
        list.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "text.book.closed.fill")
                                .foregroundStyle(.secondary)
                            Text("Custom Dictionary")
                                .font(.headline)
                        }
                        Text("Words, names, or technical terms that should always be spelled correctly. Whispr uses these during transcription cleanup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Add row
                        HStack(spacing: 8) {
                            TextField("Add a word or name…", text: $newTerm)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { addTerm() }
                            Button("Add") { addTerm() }
                                .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Term list
                if terms.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No custom terms yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Add names, acronyms, or domain words above so Whispr always spells them right.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    GroupBox {
                        VStack(spacing: 1) {
                            ForEach(Array(terms.enumerated()), id: \.offset) { index, term in
                                HStack {
                                    Text(term)
                                        .font(.body)
                                    Spacer()
                                    Button {
                                        deleteTerm(at: index)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Remove \(term)")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Color(NSColor.controlBackgroundColor)
                                        .opacity(index.isMultiple(of: 2) ? 0.5 : 0.8)
                                )
                                if index < terms.count - 1 {
                                    Divider().padding(.leading, 12)
                                }
                            }
                        }
                        .cornerRadius(8)
                        .padding(0)
                    }
                }
            }
            .padding(24)
        }
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Avoid duplicates (case-insensitive)
        guard !terms.contains(where: { $0.lowercased() == trimmed.lowercased() }) else {
            newTerm = ""
            return
        }
        var updated = terms
        updated.append(trimmed)
        appState.customVocabulary = joinTerms(updated)
        newTerm = ""
    }

    private func deleteTerm(at index: Int) {
        var updated = terms
        guard updated.indices.contains(index) else { return }
        updated.remove(at: index)
        appState.customVocabulary = joinTerms(updated)
    }
}

// MARK: - Snippets tab

struct DashboardSnippetsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEditor = false
    @State private var editingMacro: VoiceMacro?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "text.badge.plus")
                                    .foregroundStyle(.secondary)
                                Text("Voice Snippets")
                                    .font(.headline)
                            }
                            Spacer()
                            Button {
                                editingMacro = nil
                                showingEditor = true
                            } label: {
                                Label("Add Snippet", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        Text("Say the trigger phrase while dictating and Whispr will instantly paste the full expansion — no post-processing needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Macro list
                if appState.voiceMacros.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "music.mic")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No snippets yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Add a snippet above. Say its trigger and Whispr pastes the full text immediately.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    GroupBox {
                        VStack(spacing: 1) {
                            ForEach(Array(appState.voiceMacros.enumerated()), id: \.element.id) { index, macro in
                                SnippetRow(
                                    macro: macro,
                                    isLast: index == appState.voiceMacros.count - 1,
                                    rowTint: index.isMultiple(of: 2) ? 0.5 : 0.8,
                                    onEdit: {
                                        editingMacro = macro
                                        showingEditor = true
                                    },
                                    onDelete: {
                                        appState.voiceMacros.removeAll { $0.id == macro.id }
                                    }
                                )
                            }
                        }
                        .cornerRadius(8)
                        .padding(0)
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingEditor, onDismiss: { editingMacro = nil }) {
            VoiceMacroEditorView(isPresented: $showingEditor, macro: $editingMacro)
                .environmentObject(appState)
        }
    }
}

// MARK: - Voice Clone tab

struct DashboardVoiceCloneTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showConfirmation = false

    private var selectedSamples: [VoiceSample] {
        appState.selectedVoiceCloneSamples()
    }

    private var totalMinutes: Double {
        Double(selectedSamples.reduce(0) { $0 + $1.durationMs }) / 60_000.0
    }

    private var canCreate: Bool {
        !appState.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedSamples.isEmpty
            && !appState.isCreatingVoiceClone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Intro card
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.badge.plus")
                                .foregroundStyle(.secondary)
                            Text("Create My Voice")
                                .font(.headline)
                        }
                        Text("Turn your banked voice into a cloud voice clone with ElevenLabs.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // API key entry
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ElevenLabs API Key")
                            .font(.subheadline.weight(.medium))
                        SecureField("Paste your API key here", text: $appState.elevenLabsAPIKey)
                            .textFieldStyle(.roundedBorder)
                        Text("Get a key at elevenlabs.io → Profile → API Keys")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Readiness
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Voice Bank Readiness")
                            .font(.subheadline.weight(.medium))

                        let stats = appState.voiceBankStats()
                        let bankMinutes = Double(stats.totalDurationMs) / 60_000.0

                        HStack {
                            Label(String(format: "%.1f min banked", bankMinutes), systemImage: "waveform")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if selectedSamples.isEmpty {
                                Text("No samples yet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Will upload \(selectedSamples.count) clip\(selectedSamples.count == 1 ? "" : "s") (\(String(format: "%.1f", totalMinutes)) min)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Create button + status
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            showConfirmation = true
                        } label: {
                            HStack(spacing: 6) {
                                if appState.isCreatingVoiceClone {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(appState.isCreatingVoiceClone ? "Creating…" : "Create My Voice")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCreate)
                        .confirmationDialog(
                            "Upload Voice Samples to ElevenLabs?",
                            isPresented: $showConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Upload and Create Clone", role: .none) {
                                Task { await appState.createVoiceClone() }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(
                                "This uploads \(selectedSamples.count) clip\(selectedSamples.count == 1 ? "" : "s") (\(String(format: "%.1f", totalMinutes)) minutes) of your recorded voice to ElevenLabs to create a voice clone. Continue?"
                            )
                        }

                        if !appState.voiceCloneStatus.isEmpty {
                            Text(appState.voiceCloneStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Show voice ID if available
                if !appState.clonedVoiceID.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Voice ID")
                                .font(.subheadline.weight(.medium))
                            HStack(spacing: 8) {
                                Text(appState.clonedVoiceID)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(appState.clonedVoiceID, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .help("Copy voice ID to clipboard")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Shared subviews

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

// Extracted to help the type-checker with complex nested closures in DashboardSnippetsTab.
private struct SnippetRow: View {
    let macro: VoiceMacro
    let isLast: Bool
    let rowTint: Double
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(macro.command)
                        .font(.subheadline.weight(.semibold))
                    Text(macro.payload)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                Spacer()
                Button("Edit", action: onEdit)
                    .buttonStyle(.borderless)
                    .font(.caption)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.borderless)
                .help("Delete \(macro.command)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(rowTint))
            if !isLast {
                Divider().padding(.leading, 12)
            }
        }
    }
}

private struct InsightCard: View {
    let icon: String
    let value: String
    let label: String
    var badge: String? = nil
    var badgeColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let badge {
                Text(badge)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(badgeColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct ReadinessRow: View {
    let label: String
    let detail: String
    let progress: Double
    let current: Double
    let target: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline.weight(.medium))
                Spacer()
                Text(detail).font(.caption).foregroundStyle(.secondary)
                Text(progress >= 1.0 ? "Ready" : String(format: "%.1f / %.0f min", current, target))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(progress >= 1.0 ? .green : .secondary)
            }
            ProgressView(value: progress)
                .tint(progress >= 1.0 ? .green : .accentColor)
        }
    }
}
