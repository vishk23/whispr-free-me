import Foundation

/// Pure, deterministic metrics computed from pipeline history + voice bank data.
/// No UI, no AppState dependency — pass values in, get a struct back.
struct DashboardMetrics {
    let totalDictations: Int
    let totalWords: Int
    let dictationsToday: Int
    let wordsThisWeek: Int
    let timeSavedMinutes: Double
    let currentStreakDays: Int
    let activityLast30Days: [(date: Date, count: Int)]
    let topApps: [(name: String, count: Int)]
    let avgSpeakingWPM: Double
    let voiceBankMinutes: Double

    static let empty = DashboardMetrics(
        totalDictations: 0,
        totalWords: 0,
        dictationsToday: 0,
        wordsThisWeek: 0,
        timeSavedMinutes: 0,
        currentStreakDays: 0,
        activityLast30Days: [],
        topApps: [],
        avgSpeakingWPM: 0,
        voiceBankMinutes: 0
    )

    static func compute(
        history: [PipelineHistoryItem],
        voiceBankStats: VoiceBankStats,
        voiceBankSamples: [VoiceSample]
    ) -> DashboardMetrics {
        let cal = Calendar.current
        let now = Date()

        // --- word count helper ---
        func wordCount(for item: PipelineHistoryItem) -> Int {
            let text = item.postProcessedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            }
            let raw = item.rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }

        // --- totals ---
        let totalDictations = history.count
        let totalWords = history.reduce(0) { $0 + wordCount(for: $1) }

        // --- today / this week ---
        let todayStart = cal.startOfDay(for: now)
        let dictationsToday = history.filter { cal.startOfDay(for: $0.timestamp) == todayStart }.count

        let weekStart: Date = {
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            return cal.date(from: comps) ?? todayStart
        }()
        let wordsThisWeek = history
            .filter { $0.timestamp >= weekStart }
            .reduce(0) { $0 + wordCount(for: $1) }

        // --- time saved (40 wpm typing baseline) ---
        let timeSavedMinutes = Double(totalWords) / 40.0

        // --- streak ---
        // Build set of calendar days that had at least one dictation.
        var daysWithDictation: Set<Date> = []
        for item in history {
            daysWithDictation.insert(cal.startOfDay(for: item.timestamp))
        }

        var streakDays = 0
        var checkDay = todayStart
        while daysWithDictation.contains(checkDay) {
            streakDays += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }

        // --- activity last 30 days ---
        var dayCounts: [Date: Int] = [:]
        for item in history {
            let day = cal.startOfDay(for: item.timestamp)
            dayCounts[day, default: 0] += 1
        }
        let thirtyDaysAgo = cal.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        var activityLast30Days: [(date: Date, count: Int)] = []
        var cursor = thirtyDaysAgo
        while cursor <= todayStart {
            activityLast30Days.append((date: cursor, count: dayCounts[cursor] ?? 0))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        // --- top apps (top 5 by count, skip nil/empty) ---
        var appCounts: [String: Int] = [:]
        for item in history {
            if let name = item.contextAppName, !name.isEmpty {
                appCounts[name, default: 0] += 1
            }
        }
        let topApps = appCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (name: $0.key, count: $0.value) }

        // --- avg speaking WPM from voice bank samples ---
        let totalSampleWords = voiceBankSamples.reduce(0) { $0 + $1.wordCount }
        let totalSampleDurationMin = Double(voiceBankSamples.reduce(0) { $0 + $1.durationMs }) / 60_000.0
        let avgSpeakingWPM: Double = totalSampleDurationMin > 0
            ? Double(totalSampleWords) / totalSampleDurationMin
            : 0

        // --- voice bank minutes ---
        let voiceBankMinutes = Double(voiceBankStats.totalDurationMs) / 60_000.0

        return DashboardMetrics(
            totalDictations: totalDictations,
            totalWords: totalWords,
            dictationsToday: dictationsToday,
            wordsThisWeek: wordsThisWeek,
            timeSavedMinutes: timeSavedMinutes,
            currentStreakDays: streakDays,
            activityLast30Days: activityLast30Days,
            topApps: topApps,
            avgSpeakingWPM: avgSpeakingWPM,
            voiceBankMinutes: voiceBankMinutes
        )
    }
}
