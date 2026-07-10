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

    func testEmptyVocabularyNeverFlags() {
        XCTAssertFalse(DictionaryEchoGuard.isEcho(transcript: "anything at all", vocabulary: []))
    }
}
