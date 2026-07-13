import XCTest
@testable import Transcription

final class RefusalDetectorTests: XCTestCase {

    func testStockRefusalReplacingUserWordsIsDetected() {
        // Real incident: the cleanup LLM answered the transcript instead of
        // cleaning it, and its refusal got pasted into an iMessage.
        XCTAssertTrue(RefusalDetector.isRefusal(
            output: "I\u{2019}m sorry, but I can\u{2019}t help with that.",
            rawTranscript: "Yo, what are these Jews up to in Miami?"
        ))
    }

    func testRefusalVariantsAreDetected() {
        for output in [
            "I cannot assist with that request.",
            "I can't help with this.",
            "Sorry, I am unable to comply with that.",
            "As an AI, I cannot provide that."
        ] {
            XCTAssertTrue(
                RefusalDetector.isRefusal(output: output, rawTranscript: "tell me about the game last night"),
                output
            )
        }
    }

    func testGenuinelyDictatedApologySurvives() {
        // The user actually SAID a refusal-shaped sentence — it must paste.
        XCTAssertFalse(RefusalDetector.isRefusal(
            output: "I\u{2019}m sorry, but I can\u{2019}t help with that.",
            rawTranscript: "i'm sorry but i can't help with that"
        ))
    }

    func testApologyOpeningALongerMessageSurvives() {
        XCTAssertFalse(RefusalDetector.isRefusal(
            output: "I\u{2019}m sorry for the delay. The migration finished last night and the dashboards are back up, so you can rerun the report whenever works for you.",
            rawTranscript: "im sorry for the delay the migration finished last night and the dashboards are back up so you can rerun the report whenever works for you"
        ))
    }

    func testNormalCleanupIsNotFlagged() {
        XCTAssertFalse(RefusalDetector.isRefusal(
            output: "Can you move the meeting to Friday?",
            rawTranscript: "um can you move the meeting to uh friday"
        ))
    }
}
