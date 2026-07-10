import Foundation

/// Cuts the dead air after the speaker's last word before the WAV is uploaded. Whisper
/// hallucinates filler ("Thank you.", "Subtitles by...") on trailing silence; audio that
/// never reaches the model can't be hallucinated on. Trailing-only by design: trimming
/// the front would shift every segment timestamp the energy probe later relies on.
public enum TrailingSilenceTrimmer {
    /// Detection window for "is anyone speaking here".
    static let windowSeconds = 0.03
    /// Audio kept after the last voiced window, so a soft trailing syllable survives.
    static let hangoverSeconds = 1.0
    /// Rewrite the file only when it actually shortens the clip meaningfully.
    static let minimumSavingSeconds = 0.75

    /// Returns `wavData` with trailing silence cut down to the hangover, or the input
    /// unchanged when it isn't a recorder WAV, has no voiced audio, or the saving is
    /// too small to matter.
    public static func trim(wavData: Data) -> Data {
        guard let wav = WAVFile(data: wavData) else { return wavData }
        let samples = wav.samples
        let rate = wav.sampleRate
        let window = max(1, Int(windowSeconds * rate))
        let floor = Double(HallucinationFilter.energySilenceFloor)

        var lastVoicedEnd: Int?
        var start = 0
        while start < samples.count {
            let end = min(start + window, samples.count)
            var sumSquares = 0.0
            for i in start..<end {
                let v = Double(samples[i]) / 32768.0
                sumSquares += v * v
            }
            if (sumSquares / Double(end - start)).squareRoot() >= floor {
                lastVoicedEnd = end
            }
            start = end
        }

        guard let lastVoicedEnd else { return wavData } // all-silent: downstream guards own it
        let keep = min(samples.count, lastVoicedEnd + Int(hangoverSeconds * rate))
        guard samples.count - keep >= Int(minimumSavingSeconds * rate) else { return wavData }
        return WAVFile.pcm16MonoData(samples: Array(samples[0..<keep]), sampleRate: rate)
    }
}
