import XCTest
@testable import Transcription

final class FillerFilterTests: XCTestCase {

    func testStripsFillerWords() {
        XCTAssertEqual(
            FillerFilter.clean("um so can you uh move the meeting"),
            "so can you move the meeting"
        )
        XCTAssertEqual(
            FillerFilter.clean("Uh, I think, um, we should go"),
            "I think, we should go"
        )
    }

    func testCollapsesStutters() {
        XCTAssertEqual(
            FillerFilter.clean("the the the meeting is on"),
            "the meeting is on"
        )
    }

    func testTwoRepeatsAreKeptDeliberate() {
        // "very very" is emphasis, not a stutter.
        XCTAssertEqual(
            FillerFilter.clean("that is very very good"),
            "that is very very good"
        )
    }

    func testWordsContainingFillersSurvive() {
        XCTAssertEqual(FillerFilter.clean("the umbrella is uhlstrom's"), "the umbrella is uhlstrom's")
    }

    func testCleanTextUntouched() {
        let text = "Move the meeting to Friday."
        XCTAssertEqual(FillerFilter.clean(text), text)
    }
}
