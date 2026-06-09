import AVFoundation
import XCTest
@testable import VoiceBank

final class VoiceBankMetricsTests: XCTestCase {
    func testWordCountCountsWhitespaceSeparatedTokens() {
        XCTAssertEqual(VoiceBankMetrics.wordCount("hello there world"), 3)
        XCTAssertEqual(VoiceBankMetrics.wordCount("  spaced   out \n words "), 3)
        XCTAssertEqual(VoiceBankMetrics.wordCount(""), 0)
        XCTAssertEqual(VoiceBankMetrics.wordCount("   "), 0)
    }

    func testWavDurationMatchesWrittenFrames() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
        )!
        let frames = AVAudioFrameCount(8_000) // 0.5s at 16 kHz
        // Use the initializer that keeps Int16 as the processing format to avoid
        // a codec-conversion path that traps on macOS 26 (Tahoe) in unsigned tests.
        var file: AVAudioFile? = try AVAudioFile(
            forWriting: url, settings: format.settings,
            commonFormat: .pcmFormatInt16, interleaved: true
        )
        let buffer = AVAudioPCMBuffer(pcmFormat: file!.processingFormat, frameCapacity: frames)!
        buffer.frameLength = frames
        try file!.write(from: buffer)
        file = nil // flush + close before reading

        let duration = VoiceBankMetrics.wavDurationSeconds(at: url)
        XCTAssertNotNil(duration)
        XCTAssertEqual(duration!, 0.5, accuracy: 0.05)

        XCTAssertNil(VoiceBankMetrics.wavDurationSeconds(
            at: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).wav")
        ))
        try? FileManager.default.removeItem(at: url)
    }
}
