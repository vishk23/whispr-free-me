import XCTest
@testable import Transcription

final class CorrectionLearnerTests: XCTestCase {

    func testLearnsRespelledBrandNames() {
        let learned = CorrectionLearner.extractCorrections(
            pasted: "Want to grab lunch at Kava or Duncan after?",
            edited: "Want to grab lunch at Cava or Dunkin' after?",
            existingVocabulary: []
        )
        XCTAssertEqual(learned, ["Cava", "Dunkin'"])
    }

    func testIgnoresFullRewrites() {
        // More than half the words changed — that's a rewrite, not a correction.
        XCTAssertEqual(
            CorrectionLearner.extractCorrections(
                pasted: "Want to grab lunch at Kava after?",
                edited: "Actually never mind about all that entirely",
                existingVocabulary: []
            ),
            []
        )
    }

    func testIgnoresUnrelatedWordSwaps() {
        // "tomorrow" -> "Friday" is an intent change, not a phonetic correction.
        XCTAssertEqual(
            CorrectionLearner.extractCorrections(
                pasted: "See you tomorrow at noon",
                edited: "See you Friday at noon",
                existingVocabulary: []
            ),
            []
        )
    }

    func testSkipsWordsAlreadyInVocabulary() {
        XCTAssertEqual(
            CorrectionLearner.extractCorrections(
                pasted: "lunch at Kava today",
                edited: "lunch at Cava today",
                existingVocabulary: ["Cava"]
            ),
            []
        )
    }

    func testNoEditsLearnsNothing() {
        XCTAssertEqual(
            CorrectionLearner.extractCorrections(
                pasted: "Nothing changed here",
                edited: "Nothing changed here",
                existingVocabulary: []
            ),
            []
        )
    }

    func testInsertedWordsAreNotCorrections() {
        // Adding words around the paste isn't a respelling.
        XCTAssertEqual(
            CorrectionLearner.extractCorrections(
                pasted: "grab lunch at noon",
                edited: "let's grab lunch at noon today",
                existingVocabulary: []
            ),
            []
        )
    }

    func testShortWordsAreIgnored() {
        XCTAssertEqual(
            CorrectionLearner.extractCorrections(
                pasted: "go to op now",
                edited: "go to up now",
                existingVocabulary: []
            ),
            []
        )
    }
}
