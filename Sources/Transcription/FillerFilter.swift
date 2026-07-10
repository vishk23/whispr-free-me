import Foundation

/// Deterministic filler and stutter removal (Handy's text.rs pattern) — a
/// zero-latency pre-clean for the offline path, where the on-device cleanup
/// model is weaker than the cloud LLM. Only unambiguous English hesitation
/// sounds are stripped; words that merely contain them are untouched.
public enum FillerFilter {
    static let fillers: Set<String> = ["uh", "uhh", "um", "umm", "erm", "mhm", "hmm"]
    /// Three or more consecutive identical words is a stutter; two can be
    /// deliberate emphasis ("very very good").
    static let stutterThreshold = 3

    public static func clean(_ text: String) -> String {
        let tokens = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var kept: [String] = []
        var runWord = ""
        var runLength = 0

        for token in tokens {
            let core = token.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters)
            if fillers.contains(core) { continue }

            if core == runWord, !core.isEmpty {
                runLength += 1
                if runLength >= stutterThreshold {
                    // Replace the whole run with a single instance.
                    while kept.count > 1, keptCore(kept[kept.count - 1]) == core, keptCore(kept[kept.count - 2]) == core {
                        kept.removeLast()
                    }
                    if keptCore(kept.last ?? "") == core { continue }
                }
            } else {
                runWord = core
                runLength = 1
            }
            kept.append(token)
        }

        let result = kept.joined(separator: " ")
        return result.isEmpty ? text : result
    }

    private static func keptCore(_ token: String) -> String {
        token.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters)
    }
}
