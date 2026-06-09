import Foundation

public struct WhisperSegment: Equatable {
    public let text: String
    public let noSpeechProb: Double?
    public init(text: String, noSpeechProb: Double?) { self.text = text; self.noSpeechProb = noSpeechProb }
}

public enum HallucinationFilter {
    public static let phrases: Set<String> = [
        "thank you", "thank you for watching", "thank you very much", "thank you so much",
        "thanks for watching", "please subscribe", "like and subscribe",
        "subtitles by", "subtitles by the amara.org community", "you", "okay", "ok", "bye"
    ]
    public static let noSpeechThreshold = 0.1

    public static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
    }

    /// Removes trailing hallucinated segments (a known phrase whose segment is
    /// flagged by Whisper as likely-silence) and returns the cleaned transcript.
    public static func strip(text: String, segments: [WhisperSegment]) -> String {
        guard !segments.isEmpty else { return text } // conservative: can't confirm without segment data
        var kept = segments
        while let last = kept.last,
              phrases.contains(normalize(last.text)),
              let prob = last.noSpeechProb, prob >= noSpeechThreshold {
            kept.removeLast()
        }
        if kept.count == segments.count { return text }       // nothing stripped
        return kept.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
