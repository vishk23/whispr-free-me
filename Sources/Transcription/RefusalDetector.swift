import Foundation

/// Detects a cleanup model REFUSING instead of cleaning ("I'm sorry, but I
/// can't help with that.") so the pipeline can fall back to the speaker's real
/// words. A dictation tool is a keyboard: whatever the user said, their words
/// must paste — the LLM is a formatting layer, never a content gate.
///
/// Deliberately conservative in the other direction too: when the user
/// genuinely dictated a refusal-shaped sentence, the raw transcript starts with
/// the same opener and the output is NOT flagged.
public enum RefusalDetector {
    /// Openers of stock assistant refusals, matched against the normalized
    /// (apostrophe-free) start of the output.
    static let refusalOpeners: [String] = [
        "im sorry", "i am sorry", "sorry, i", "sorry, but i",
        "i cant help", "i cannot help", "i cant assist", "i cannot assist",
        "i cant provide", "i cannot provide", "i cant comply", "i cannot comply",
        "im unable to", "i am unable to", "i wont be able to",
        "as an ai", "im not able to", "i am not able to"
    ]
    /// Real refusals are terse; a long output is content, not a refusal.
    static let maxRefusalLength = 180

    public static func isRefusal(output: String, rawTranscript: String) -> Bool {
        let normalizedOutput = normalize(output)
        guard !normalizedOutput.isEmpty, normalizedOutput.count <= maxRefusalLength else { return false }
        guard let opener = refusalOpeners.first(where: { normalizedOutput.hasPrefix($0) }) else {
            return false
        }
        // If the speaker's own words begin with a refusal-shaped opener, the
        // output is a faithful cleanup, not a model refusal.
        let normalizedRaw = normalize(rawTranscript)
        if refusalOpeners.contains(where: { normalizedRaw.hasPrefix($0) }) { return false }
        _ = opener
        return true
    }

    /// Lowercase, drop apostrophes (raw ASR writes "im sorry", models write
    /// "I'm sorry" — both must compare equal), trim leading non-letters so
    /// quoted or bulleted refusals still match.
    static func normalize(_ text: String) -> String {
        var s = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "")
            .replacingOccurrences(of: "\u{2018}", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = s.first, !first.isLetter {
            s.removeFirst()
        }
        return s
    }
}
