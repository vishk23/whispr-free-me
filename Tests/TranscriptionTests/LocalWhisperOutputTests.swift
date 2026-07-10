import XCTest
@testable import Transcription

final class LocalWhisperOutputTests: XCTestCase {

    func testParsesSegmentsAndJoinedText() throws {
        let json = """
        {"systeminfo": "x", "model": {}, "params": {}, "result": {"language": "en"},
         "transcription": [
           {"timestamps": {"from": "00:00:00,000", "to": "00:00:02,500"},
            "offsets": {"from": 0, "to": 2500}, "text": " Hello there."},
           {"timestamps": {"from": "00:00:02,500", "to": "00:00:03,400"},
            "offsets": {"from": 2500, "to": 3400}, "text": " Thank you."}
         ]}
        """
        let output = try XCTUnwrap(LocalWhisperOutput.parse(Data(json.utf8)))
        XCTAssertEqual(output.text, " Hello there. Thank you.")
        XCTAssertEqual(output.segments.count, 2)
        XCTAssertEqual(output.segments[1].start, 2.5)
        XCTAssertEqual(output.segments[1].end, 3.4)
        XCTAssertNil(output.segments[1].noSpeechProb)
    }

    func testMalformedJSONReturnsNil() {
        XCTAssertNil(LocalWhisperOutput.parse(Data("not json".utf8)))
        XCTAssertNil(LocalWhisperOutput.parse(Data("{}".utf8)))
    }
}
