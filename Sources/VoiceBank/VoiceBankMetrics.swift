import AVFoundation
import Foundation

enum VoiceBankMetrics {
    /// Number of whitespace/newline-separated word tokens in a transcript.
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Duration in seconds of a PCM/WAV file, or nil if it cannot be read.
    static func wavDurationSeconds(at url: URL) -> Double? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return nil }
        return Double(file.length) / sampleRate
    }
}
