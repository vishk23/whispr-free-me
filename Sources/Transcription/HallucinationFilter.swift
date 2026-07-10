import Foundation

public struct WhisperSegment: Equatable {
    public let text: String
    public let noSpeechProb: Double?
    public let start: Double?
    public let end: Double?
    public init(text: String, noSpeechProb: Double?, start: Double? = nil, end: Double? = nil) {
        self.text = text
        self.noSpeechProb = noSpeechProb
        self.start = start
        self.end = end
    }
    public var duration: Double? {
        guard let start, let end else { return nil }
        return max(0, end - start)
    }
}

public enum HallucinationFilter {
    /// Known phrases Whisper hallucinates on silence/pauses at the end of a clip.
    public static let phrases: Set<String> = [
        "thank you", "thank you for watching", "thank you very much", "thank you so much",
        "thanks for watching", "please subscribe", "like and subscribe",
        "subtitles by", "subtitles by the amara.org community", "you", "okay", "ok", "bye"
    ]
    /// Phrases that are commonly *intentional* (e.g. a message/email sign-off). These
    /// are stripped only when Whisper itself flags the segment as silence — never on
    /// the short-trailing-segment heuristic — so a deliberate "Thank you." survives.
    static let silenceOnlyPhrases: Set<String> = [
        "thank you", "thank you very much", "thank you so much"
    ]
    public static let noSpeechThreshold = 0.1
    /// A hallucinated trailing filler is a brief, isolated segment. Real sentences that
    /// merely *contain* a filler word are not their own short segment, so duration
    /// discriminates the artifact from genuine speech.
    static let maxFillerDuration = 1.5
    /// Window mean-RMS below this is silence: no voice was recorded during the segment,
    /// so a confident filler there is hallucinated. Raw samples normalized to [-1, 1];
    /// whispered speech measures >= ~0.01, ambient room noise <= ~0.005.
    public static let energySilenceFloor: Float = 0.006

    public static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
    }

    /// Removes trailing hallucinated segments. A trailing segment is dropped when it is a
    /// known filler phrase AND either Whisper flagged it as silence (`no_speech_prob` high)
    /// OR it is a short, isolated trailing segment — the signature of a confidently
    /// hallucinated "Okay."/"Bye." appended after the speaker stops. Real speech preceding
    /// the filler is preserved.
    public static func strip(
        text: String,
        segments: [WhisperSegment],
        windowRMS: ((_ start: Double, _ end: Double) -> Float)? = nil
    ) -> String {
        guard !segments.isEmpty else { return text } // can't confirm without segment data
        var kept = segments
        while let last = kept.last {
            let normalized = normalize(last.text)
            guard phrases.contains(normalized) else { break }
            let highSilence = (last.noSpeechProb ?? 0) >= noSpeechThreshold
            let shortTrailing = (last.duration ?? .greatestFiniteMagnitude) < maxFillerDuration
            // Audio evidence beats Whisper's own confidence: if the recorded audio during
            // this segment's window is silent, no one spoke it — a confident "Thank you."
            // there is hallucinated. A deliberately spoken sign-off has voice energy and
            // survives. Requires timestamps and a probe; otherwise falls back to the
            // metadata-only rules.
            let silentWindow: Bool
            if let windowRMS, let start = last.start, let end = last.end, end > start {
                silentWindow = windowRMS(start, end) < energySilenceFloor
            } else {
                silentWindow = false
            }
            let strippable = silenceOnlyPhrases.contains(normalized)
                ? (highSilence || silentWindow)
                : (highSilence || shortTrailing || silentWindow)
            guard strippable else { break }
            kept.removeLast()
        }
        if kept.count == segments.count { return text } // nothing stripped
        return kept.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
