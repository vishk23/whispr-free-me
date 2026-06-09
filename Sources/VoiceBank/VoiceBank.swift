import Foundation

/// Single entry point the app uses to bank dictations and manage the dataset.
/// Owns a `VoiceBank/` directory (audio copies + its own SQLite store) under
/// the given base directory.
final class VoiceBank {
    let audioDirectory: URL
    private let store: VoiceBankStore
    private let fileManager = FileManager.default

    init(baseDirectory: URL) {
        let bankDir = baseDirectory.appendingPathComponent("VoiceBank", isDirectory: true)
        try? FileManager.default.createDirectory(at: bankDir, withIntermediateDirectories: true)
        audioDirectory = bankDir
        store = VoiceBankStore(storeURL: bankDir.appendingPathComponent("VoiceBank.sqlite"))
    }

    /// Copies the WAV and records metadata when the clip passes the quality
    /// gate. Returns the banked sample, or nil if skipped or on I/O failure.
    @discardableResult
    func bankIfEligible(
        sourceWavURL: URL,
        transcript: String,
        intent: String,
        appBundleId: String?,
        sampleRate: Int = 16_000
    ) -> VoiceSample? {
        let duration = VoiceBankMetrics.wavDurationSeconds(at: sourceWavURL) ?? 0
        let candidate = VoiceSampleCandidate(
            transcript: transcript, intent: intent, durationSeconds: duration
        )
        guard VoiceBankQualityGate.shouldBank(candidate) else { return nil }

        let fileName = UUID().uuidString + ".wav"
        let destination = audioDirectory.appendingPathComponent(fileName)
        do {
            try fileManager.copyItem(at: sourceWavURL, to: destination)
        } catch {
            return nil
        }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let sample = VoiceSample(
            createdAt: Date(),
            audioFileName: fileName,
            transcript: trimmed,
            durationMs: Int(duration * 1000),
            sampleRate: sampleRate,
            wordCount: VoiceBankMetrics.wordCount(trimmed),
            appBundleId: appBundleId
        )
        do {
            try store.insert(sample)
        } catch {
            try? fileManager.removeItem(at: destination)
            return nil
        }
        return sample
    }

    func allSamples() -> [VoiceSample] { store.allSamples() }

    func stats() -> VoiceBankStats { store.stats() }

    func audioURL(for sample: VoiceSample) -> URL {
        audioDirectory.appendingPathComponent(sample.audioFileName)
    }

    func delete(id: UUID) {
        do {
            if let fileName = try store.delete(id: id) {
                try? fileManager.removeItem(at: audioDirectory.appendingPathComponent(fileName))
            }
        } catch { }
    }

    func deleteAll() {
        let names = (try? store.deleteAll()) ?? []
        for name in names {
            try? fileManager.removeItem(at: audioDirectory.appendingPathComponent(name))
        }
    }
}
