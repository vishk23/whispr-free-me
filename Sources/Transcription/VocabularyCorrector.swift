import Foundation

/// Deterministic post-STT vocabulary enforcement: rewrites near-miss transcriptions of
/// user-dictionary terms to their authoritative spelling. Match tiers, all
/// conservative because a wrong correction is worse than a missed one:
/// 1. compact-exact — the token window equals the term once spaces/punctuation are
///    dropped ("chat g p t" -> "ChatGPT", "chargebee" -> "ChargeBee")
/// 2. fuzzy — single token whose edit-distance ratio to the term is <= 0.34 AND whose
///    phonetic code matches ("grok" -> "Groq", "kava" -> "Cava", "duncan" ->
///    "Dunkin'"), while "grow" keeps its distinct code and survives. Unlike classic
///    Soundex the first letter is grouped too, so K/C homophones can match.
public enum VocabularyCorrector {
    static let maxEditRatio = 0.34
    static let minFuzzyLength = 3

    public static func correct(_ text: String, vocabulary: [String]) -> String {
        let terms = vocabulary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty, !text.isEmpty else { return text }

        var tokens = tokenize(text)
        for term in terms {
            tokens = applyTerm(term, to: tokens)
        }
        return render(tokens)
    }

    // MARK: - Token model

    struct Token {
        var leading: String   // leading punctuation
        var core: String      // the word
        var trailing: String  // trailing punctuation
        var separator: String // whitespace that followed the token
    }

    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var index = text.startIndex
        while index < text.endIndex {
            // consume non-whitespace run
            var wordEnd = index
            while wordEnd < text.endIndex, !text[wordEnd].isWhitespace { wordEnd = text.index(after: wordEnd) }
            let raw = String(text[index..<wordEnd])
            var sepEnd = wordEnd
            while sepEnd < text.endIndex, text[sepEnd].isWhitespace { sepEnd = text.index(after: sepEnd) }
            let separator = String(text[wordEnd..<sepEnd])
            if !raw.isEmpty {
                let leading = String(raw.prefix(while: { !$0.isLetter && !$0.isNumber }))
                let remainder = raw.dropFirst(leading.count)
                let trailingCount = remainder.reversed().prefix(while: { !$0.isLetter && !$0.isNumber }).count
                let core = String(remainder.dropLast(trailingCount))
                let trailing = String(remainder.suffix(trailingCount))
                tokens.append(Token(leading: leading, core: core, trailing: trailing, separator: separator))
            }
            index = sepEnd
        }
        return tokens
    }

    static func render(_ tokens: [Token]) -> String {
        tokens.map { $0.leading + $0.core + $0.trailing + $0.separator }.joined()
    }

    // MARK: - Matching

    private static func applyTerm(_ term: String, to tokens: [Token]) -> [Token] {
        let termCompact = compact(term)
        guard !termCompact.isEmpty else { return tokens }
        let termTokenCount = term.split(whereSeparator: { $0.isWhitespace }).count
        let maxWindow = max(termTokenCount, min(6, termCompact.count)) // spelled-out letters
        var result = tokens
        var i = 0
        while i < result.count {
            var replaced = false
            var window = maxWindow
            while window >= 1, i + window <= result.count {
                let slice = result[i..<(i + window)]
                let joinedCompact = slice.map { compact($0.core) }.joined()
                if !joinedCompact.isEmpty, joinedCompact == termCompact {
                    if window == 1 && slice.first!.core == term {
                        break // already the authoritative spelling
                    }
                    result = replace(range: i..<(i + window), in: result, with: term)
                    replaced = true
                    break
                }
                window -= 1
            }
            if !replaced, fuzzyMatches(result[i].core, term: term) {
                result = replace(range: i..<(i + 1), in: result, with: term)
            }
            i += 1
        }
        return result
    }

    private static func replace(range: Range<Int>, in tokens: [Token], with term: String) -> [Token] {
        let first = tokens[range.lowerBound]
        let last = tokens[range.upperBound - 1]
        let merged = Token(leading: first.leading, core: term, trailing: last.trailing, separator: last.separator)
        var result = tokens
        result.replaceSubrange(range, with: [merged])
        return result
    }

    static func fuzzyMatches(_ word: String, term: String) -> Bool {
        // Compare compact forms so punctuation inside the vocab term ("Dunkin'")
        // doesn't inflate the edit distance.
        let w = compact(word)
        let t = compact(term)
        guard w != t else { return true } // case/punctuation-only difference
        guard w.count >= minFuzzyLength, t.count >= minFuzzyLength else { return false }
        let distance = levenshtein(w, t)
        let ratio = Double(distance) / Double(max(w.count, t.count))
        guard ratio <= maxEditRatio else { return false }
        return phoneticCode(w) == phoneticCode(t) && firstLettersCompatible(w, t)
    }

    /// Word-initial sounds are far more discriminating than the coarse phonetic
    /// groups — grouping J with C let a real dictation's "Java" be rewritten to
    /// "Cava". Only C/K/Q can genuinely sound identical at position 0.
    static func firstLettersCompatible(_ a: String, _ b: String) -> Bool {
        guard let fa = a.first, let fb = b.first else { return false }
        if fa == fb { return true }
        let hardC: Set<Character> = ["c", "k", "q"]
        return hardC.contains(fa) && hardC.contains(fb)
    }

    static func compact(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a), bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }
        var previous = Array(0...bChars.count)
        var current = [Int](repeating: 0, count: bChars.count + 1)
        for (i, aChar) in aChars.enumerated() {
            current[0] = i + 1
            for (j, bChar) in bChars.enumerated() {
                let cost = aChar == bChar ? 0 : 1
                current[j + 1] = min(previous[j + 1] + 1, current[j] + 1, previous[j] + cost)
            }
            swap(&previous, &current)
        }
        return previous[bChars.count]
    }

    /// Soundex-style phonetic code with the first letter grouped like every other
    /// letter (classic Soundex keeps it literal, which blocks K/C homophones such
    /// as "kava"/"Cava"). Consecutive same-group consonants collapse; vowels and
    /// h/w/y drop. Non-ASCII input falls back to the word itself so two different
    /// accented words never collide via an empty code.
    static func phoneticCode(_ word: String) -> String {
        let letters = word.lowercased().unicodeScalars.filter { $0.isASCII && CharacterSet.lowercaseLetters.contains($0) }
        guard !letters.isEmpty else { return word }
        func code(_ c: UnicodeScalar) -> Character? {
            switch c {
            case "b", "f", "p", "v": return "1"
            case "c", "g", "j", "k", "q", "s", "x", "z": return "2"
            case "d", "t": return "3"
            case "l": return "4"
            case "m", "n": return "5"
            case "r": return "6"
            default: return nil // vowels + h/w/y drop
            }
        }
        var result = ""
        var lastCode: Character?
        for scalar in letters {
            let c = code(scalar)
            if let c, c != lastCode {
                result.append(c)
            }
            if scalar != "h" && scalar != "w" { lastCode = c }
        }
        return result.isEmpty ? word : result
    }
}

/// Detects Whisper parroting the injected vocabulary prompt back on silent/noise-only
/// audio (OpenWhispr's dictionary-echo failure). A real sentence merely *uses* some
/// vocabulary; an echo *is* the vocabulary.
public enum DictionaryEchoGuard {
    static let minTextComposition = 0.9  // >= 90% of transcript tokens are vocab words
    static let minVocabularyUsage = 0.7  // >= 70% of vocab terms appear

    public static func isEcho(transcript: String, vocabulary: [String]) -> Bool {
        let vocabWords = Set(
            vocabulary.flatMap { $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) }
                .map { $0.lowercased() }
                .filter { !$0.isEmpty }
        )
        guard !vocabWords.isEmpty else { return false }
        let words = transcript.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { $0.lowercased() }
        guard !words.isEmpty else { return false }
        let vocabHits = words.filter { vocabWords.contains($0) }
        let composition = Double(vocabHits.count) / Double(words.count)
        let usage = Double(Set(vocabHits).count) / Double(vocabWords.count)
        return composition >= minTextComposition && usage >= minVocabularyUsage
    }

    /// Whisper can also parrot the vocabulary prompt onto the quiet tail of REAL
    /// speech ("...feeling productive. Cava, Dunkin'"). The signature is precise:
    /// the transcript ends with two or more vocabulary terms in prompt order,
    /// comma-joined exactly as the prompt joins them. A genuine spoken list uses
    /// "and", different order, or continues the sentence — all left untouched.
    /// Single trailing terms are never stripped ("...coffee at Dunkin'" is real).
    public static func stripTrailingPromptEcho(transcript: String, vocabulary: [String]) -> String {
        let terms = vocabulary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard terms.count >= 2 else { return transcript }

        var body = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        // Tolerate a trailing period Whisper sometimes appends to the echo.
        if body.hasSuffix(".") {
            body.removeLast()
        }

        for start in 0...(terms.count - 2) {
            let candidate = terms[start...].joined(separator: ", ")
            if body.lowercased().hasSuffix(candidate.lowercased()) {
                let stripped = String(body.dropLast(candidate.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // Refuse to reduce the transcript to nothing — that case is the
                // whole-transcript echo, which isEcho already handles.
                guard !stripped.isEmpty else { return transcript }
                return stripped
            }
        }
        return transcript
    }
}
