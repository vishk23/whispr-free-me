import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    private var metrics: DashboardMetrics {
        DashboardMetrics.compute(
            history: appState.pipelineHistory,
            voiceBankStats: appState.voiceBankStats(),
            voiceBankSamples: appState.voiceBankSamples()
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                statCardsSection
                activityChartSection
                topAppsSection
                voiceBankReadinessSection
            }
            .padding(24)
        }
        .frame(width: 720, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Voice")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Dictation activity and voice bank stats")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stat Cards

    private var statCardsSection: some View {
        let m = metrics
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            StatCard(value: "\(m.totalDictations)", label: "Total dictations")
            StatCard(value: "\(m.totalWords)", label: "Total words")
            StatCard(value: formatTimeSaved(m.timeSavedMinutes), label: "Time saved")
            StatCard(value: m.currentStreakDays > 0 ? "\(m.currentStreakDays) 🔥" : "0", label: "Day streak")
            StatCard(value: m.avgSpeakingWPM > 0 ? "\(Int(m.avgSpeakingWPM))" : "—", label: "Avg speaking WPM")
            StatCard(value: String(format: "%.1f min", m.voiceBankMinutes), label: "Minutes banked")
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

    // MARK: - Activity Chart

    private var activityChartSection: some View {
        let m = metrics
        // Show last 14 days for readability.
        let recent = Array(m.activityLast30Days.suffix(14))
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

    // MARK: - Top Apps

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

    // MARK: - Voice Bank Readiness

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

// MARK: - Subviews

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
