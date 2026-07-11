import XCTest
@testable import Transcription

final class VocabularyCorrectorTests: XCTestCase {

    func testCaseOnlyMismatchAdoptsVocabularySpelling() {
        XCTAssertEqual(
            VocabularyCorrector.correct("we use chargebee for billing", vocabulary: ["ChargeBee"]),
            "we use ChargeBee for billing"
        )
    }

    func testSpelledOutTermMergesToVocabularyForm() {
        XCTAssertEqual(
            VocabularyCorrector.correct("ask chat g p t about it", vocabulary: ["ChatGPT"]),
            "ask ChatGPT about it"
        )
    }

    func testPhoneticNearMissCorrects() {
        // Whisper hears "grok"; the vocabulary authority is "Groq".
        XCTAssertEqual(
            VocabularyCorrector.correct("run it on grok today", vocabulary: ["Groq"]),
            "run it on Groq today"
        )
    }

    func testSimilarRealWordIsNotClobbered() {
        // "grow" is one edit from "Groq" but phonetically distinct — must survive.
        XCTAssertEqual(
            VocabularyCorrector.correct("we want to grow fast", vocabulary: ["Groq"]),
            "we want to grow fast"
        )
    }


    func testRealWordJavaIsNotClobbered() {
        // "Java" is one edit from "Cava" and my coarse phonetic grouping matched
        // J with C — a real dictation had "Android or Java" rewritten to "Cava".
        // Word-initial J and C never sound alike; only C/K/Q merge at position 0.
        XCTAssertEqual(
            VocabularyCorrector.correct("I don't care about Android or Java", vocabulary: ["Cava"]),
            "I don't care about Android or Java"
        )
    }

    func testHomophoneFirstLetterCorrects() {
        // Whisper hears the drink; the user means the restaurant. K and C share a
        // phonetic group, so the first letter must not block the match.
        XCTAssertEqual(
            VocabularyCorrector.correct("lunch at kava today", vocabulary: ["Cava"]),
            "lunch at Cava today"
        )
    }

    func testBrandRespellingWithApostropheCorrects() {
        // "duncan" -> "Dunkin'": two edits plus an apostrophe in the vocab term.
        XCTAssertEqual(
            VocabularyCorrector.correct("grab coffee at duncan", vocabulary: ["Dunkin'"]),
            "grab coffee at Dunkin'"
        )
    }

    func testPunctuationSurvivesReplacement() {
        XCTAssertEqual(
            VocabularyCorrector.correct("Have you tried chargebee?", vocabulary: ["ChargeBee"]),
            "Have you tried ChargeBee?"
        )
    }

    func testShortWordsRequireExactMatch() {
        // Two-letter tokens must not fuzzy-match anything.
        XCTAssertEqual(
            VocabularyCorrector.correct("go to the store", vocabulary: ["Gk"]),
            "go to the store"
        )
    }

    func testExactMatchesAreUntouched() {
        XCTAssertEqual(
            VocabularyCorrector.correct("ChatGPT is fine", vocabulary: ["ChatGPT"]),
            "ChatGPT is fine"
        )
    }

    func testEmptyVocabularyIsNoOp() {
        XCTAssertEqual(
            VocabularyCorrector.correct("hello there", vocabulary: []),
            "hello there"
        )
    }
}

final class DictionaryEchoGuardTests: XCTestCase {

    func testPromptEchoIsDetected() {
        // Silence in, vocabulary out: Whisper parrots the injected prompt.
        XCTAssertTrue(DictionaryEchoGuard.isEcho(
            transcript: "ChargeBee, ChatGPT, Groq",
            vocabulary: ["ChargeBee", "ChatGPT", "Groq"]
        ))
    }

    func testRealSentenceUsingVocabularyIsNotEcho() {
        XCTAssertFalse(DictionaryEchoGuard.isEcho(
            transcript: "Can you move the ChargeBee invoice export into the ChatGPT summary flow before Friday",
            vocabulary: ["ChargeBee", "ChatGPT", "Groq"]
        ))
    }


    func testTrailingPromptEchoIsStripped() {
        // Whisper parrots the vocabulary prompt onto the quiet tail of real
        // speech: "...feeling productive. Cava, Dunkin'" (real incident).
        XCTAssertEqual(
            DictionaryEchoGuard.stripTrailingPromptEcho(
                transcript: "I'm feeling that I'm using my strengths and feeling productive. Cava, Dunkin'",
                vocabulary: ["Cava", "Dunkin'"]
            ),
            "I'm feeling that I'm using my strengths and feeling productive."
        )
    }

    func testGenuineSingleTermEndingSurvives() {
        XCTAssertEqual(
            DictionaryEchoGuard.stripTrailingPromptEcho(
                transcript: "Let's grab coffee at Dunkin'",
                vocabulary: ["Cava", "Dunkin'"]
            ),
            "Let's grab coffee at Dunkin'"
        )
    }

    func testAndJoinedListSurvives() {
        // Comma-joined prompt-order tail is the echo signature; "and" means the
        // speaker actually listed them.
        XCTAssertEqual(
            DictionaryEchoGuard.stripTrailingPromptEcho(
                transcript: "We could do Cava and Dunkin'",
                vocabulary: ["Cava", "Dunkin'"]
            ),
            "We could do Cava and Dunkin'"
        )
    }

    func testMidSentenceVocabularySurvives() {
        XCTAssertEqual(
            DictionaryEchoGuard.stripTrailingPromptEcho(
                transcript: "Cava, Dunkin' are both on the way home",
                vocabulary: ["Cava", "Dunkin'"]
            ),
            "Cava, Dunkin' are both on the way home"
        )
    }

    func testEmptyVocabularyNeverFlags() {
        XCTAssertFalse(DictionaryEchoGuard.isEcho(transcript: "anything at all", vocabulary: []))
    }
}
