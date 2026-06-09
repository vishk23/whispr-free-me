import XCTest
@testable import VoiceBank

final class HarnessTests: XCTestCase {
    func testHarnessRuns() {
        XCTAssertTrue(VoiceBankPlaceholder.ok)
    }
}
