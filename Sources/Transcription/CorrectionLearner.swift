import Foundation

/// Learns vocabulary from the user's own edits: after a dictation is pasted, the
/// caller re-reads the target field and hands both versions here. Word-level
/// alignment finds respellings ("Kava" -> "Cava", "Duncan" -> "Dunkin'"), which
/// become custom-vocabulary terms so the whole pipeline gets them right next time.
/// Deliberately conservative — an intent edit ("tomorrow" -> "Friday") must never
/// be learned as a spelling.
public enum CorrectionLearner {
    static let maxLearnedPerDictation = 3
    /// A respelling stays phonetically close; beyond this the user changed meaning.
    static let maxEditRatio = 0.5
    static let minWordLength = 3

    public static func extractCorrections(
        pasted: String,
        edited: String,
        existingVocabulary: [String]
    ) -> [String] {
        let original = words(pasted)
        let revised = words(edited)
        guard !original.isEmpty, !revised.isEmpty, original != revised else { return [] }

        let table = lcsTable(original, revised)
        let commonCount = table[original.count][revised.count]
        // More than half the dictation replaced = rewrite, not correction.
        guard original.count - commonCount <= original.count / 2 else { return [] }

        let known = Set(existingVocabulary.map { compactKey($0) })
        var learned: [String] = []
        for (was, becomes) in substitutionPairs(original, revised, table: table) {
            let wasKey = compactKey(was)
            let becomesKey = compactKey(becomes)
            guard wasKey.count >= minWordLength, becomesKey.count >= minWordLength else { continue }
            guard wasKey != becomesKey else { continue } // case/punctuation-only edit
            guard !known.contains(becomesKey) else { continue }
            let distance = VocabularyCorrector.levenshtein(wasKey, becomesKey)
            let ratio = Double(distance) / Double(max(wasKey.count, becomesKey.count))
            guard ratio <= maxEditRatio else { continue } // intent change, not respelling
            if !learned.contains(where: { compactKey($0) == becomesKey }) {
                learned.append(becomes)
            }
            if learned.count == maxLearnedPerDictation { break }
        }
        return learned
    }

    // MARK: - Internals

    /// Splits into words, trimming edge punctuation but keeping apostrophes so
    /// "Dunkin'," yields "Dunkin'".
    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).compactMap { raw -> String? in
            var word = String(raw)
            while let first = word.first, !first.isLetter, !first.isNumber {
                word.removeFirst()
            }
            while let last = word.last, !last.isLetter, !last.isNumber, last != "'", last != "\u{2019}" {
                word.removeLast()
            }
            return word.isEmpty ? nil : word
        }
    }

    static func compactKey(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func lcsTable(_ a: [String], _ b: [String]) -> [[Int]] {
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 1...a.count {
            for j in 1...b.count {
                table[i][j] = a[i - 1] == b[j - 1]
                    ? table[i - 1][j - 1] + 1
                    : max(table[i - 1][j], table[i][j - 1])
            }
        }
        return table
    }

    /// Walks the LCS backtrack and pairs up deletions with insertions inside each
    /// change block — those 1:1 pairs are the substitutions.
    private static func substitutionPairs(
        _ a: [String], _ b: [String], table: [[Int]]
    ) -> [(String, String)] {
        var pairs: [(String, String)] = []
        var deletions: [String] = []
        var insertions: [String] = []
        func flushBlock() {
            // Both collected right-to-left; reversed zip pairs them left-to-right.
            for (was, becomes) in zip(deletions.reversed(), insertions.reversed()) {
                pairs.append((was, becomes))
            }
            deletions.removeAll()
            insertions.removeAll()
        }
        var i = a.count
        var j = b.count
        while i > 0 || j > 0 {
            if i > 0, j > 0, a[i - 1] == b[j - 1] {
                flushBlock()
                i -= 1
                j -= 1
            } else if j > 0, i == 0 || table[i][j - 1] >= table[i - 1][j] {
                insertions.append(b[j - 1])
                j -= 1
            } else {
                deletions.append(a[i - 1])
                i -= 1
            }
        }
        flushBlock()
        return pairs.reversed()
    }
}
