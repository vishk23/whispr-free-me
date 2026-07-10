import XCTest
@testable import Transcription

final class SmartSpacingTests: XCTestCase {

    func testInsertsSpaceAfterWordCharacter() {
        XCTAssertTrue(SmartSpacing.needsLeadingSpace(precedingCharacter: "d", transcript: "hello"))
        XCTAssertTrue(SmartSpacing.needsLeadingSpace(precedingCharacter: ".", transcript: "New sentence"))
        XCTAssertTrue(SmartSpacing.needsLeadingSpace(precedingCharacter: "?", transcript: "Yes"))
    }

    func testNoSpaceAfterWhitespaceOrOpeners() {
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: " ", transcript: "hello"))
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: "\n", transcript: "hello"))
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: "(", transcript: "hello"))
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: "[", transcript: "hello"))
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: "\u{201C}", transcript: "hello"))
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: "'", transcript: "hello"))
    }

    func testNoSpaceWhenTranscriptStartsWithClosingPunctuation() {
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: "d", transcript: ", and more"))
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: "d", transcript: ")"))
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: "d", transcript: "."))
    }

    func testNoSpaceAtDocumentStartOrUnknownContext() {
        // nil = empty field or AX couldn't read the context — keep today's behavior.
        XCTAssertFalse(SmartSpacing.needsLeadingSpace(precedingCharacter: nil, transcript: "hello"))
    }
}
