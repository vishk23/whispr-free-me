import Foundation

/// Reads the recorder's mono PCM16 WAV output and answers "was there voice energy in
/// this time window?" — the audio-evidence side of `HallucinationFilter`. Whisper's
/// segment metadata can be confidently wrong about a hallucinated trailing filler; the
/// recorded samples cannot.
public struct WAVEnergyProbe {
    private let wav: WAVFile

    public init?(data: Data) {
        guard let wav = WAVFile(data: data) else { return nil }
        self.wav = wav
    }

    public init?(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.init(data: data)
    }

    /// Mean RMS of the samples in [start, end) seconds, normalized to [-1, 1].
    /// Windows outside the recorded audio read as 0 (no audio there means no voice there).
    public func rms(start: Double, end: Double) -> Float {
        let samples = wav.samples
        guard end > start, !samples.isEmpty else { return 0 }
        let lo = max(0, Int(start * wav.sampleRate))
        let hi = min(samples.count, Int(end * wav.sampleRate))
        guard hi > lo else { return 0 }
        var sumSquares = 0.0
        for i in lo..<hi {
            let v = Double(samples[i]) / 32768.0
            sumSquares += v * v
        }
        return Float((sumSquares / Double(hi - lo)).squareRoot())
    }
}
