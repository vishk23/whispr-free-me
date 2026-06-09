import AVFoundation
import XCTest
@testable import VoiceBank

final class VoiceBankTests: XCTestCase {
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes a mono 16 kHz PCM16 WAV of the given duration and returns its URL.
    private func makeWav(seconds: Double, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(UUID().uuidString + ".wav")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
        )!
        let frames = AVAudioFrameCount(seconds * 16_000)
        // Use the initializer that keeps Int16 as the processing format to avoid
        // a codec-conversion path that traps on macOS 26 (Tahoe) in unsigned tests.
        var file: AVAudioFile? = try AVAudioFile(
            forWriting: url, settings: format.settings,
            commonFormat: .pcmFormatInt16, interleaved: true
        )
        let buffer = AVAudioPCMBuffer(pcmFormat: file!.processingFormat, frameCapacity: frames)!
        buffer.frameLength = frames
        try file!.write(from: buffer)
        file = nil
        return url
    }

    func testBanksEligibleClipCopyingAudioAndRecordingMetadata() throws {
        let base = tempDir()
        let source = try makeWav(seconds: 1.5, in: tempDir())
        let bank = VoiceBank(baseDirectory: base)

        let sample = bank.bankIfEligible(
            sourceWavURL: source,
            transcript: "this is a banked sentence",
            intent: "dictation",
            appBundleId: "com.apple.TextEdit"
        )

        let saved = try XCTUnwrap(sample)
        XCTAssertEqual(bank.allSamples().count, 1)
        XCTAssertEqual(saved.wordCount, 5)
        XCTAssertEqual(saved.appBundleId, "com.apple.TextEdit")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bank.audioURL(for: saved).path))
        // The bank keeps its own copy, separate from the source.
        XCTAssertNotEqual(bank.audioURL(for: saved).path, source.path)
    }

    func testIneligibleClipBanksNothing() throws {
        let base = tempDir()
        let bank = VoiceBank(baseDirectory: base)

        // wrong intent
        XCTAssertNil(bank.bankIfEligible(
            sourceWavURL: try makeWav(seconds: 1.5, in: tempDir()),
            transcript: "hello there friend", intent: "command:automatic", appBundleId: nil
        ))
        // empty transcript
        XCTAssertNil(bank.bankIfEligible(
            sourceWavURL: try makeWav(seconds: 1.5, in: tempDir()),
            transcript: "   ", intent: "dictation", appBundleId: nil
        ))
        // too short
        XCTAssertNil(bank.bankIfEligible(
            sourceWavURL: try makeWav(seconds: 0.3, in: tempDir()),
            transcript: "hello there friend", intent: "dictation", appBundleId: nil
        ))

        XCTAssertEqual(bank.allSamples().count, 0)
        let contents = try FileManager.default.contentsOfDirectory(
            atPath: bank.audioDirectory.path
        ).filter { $0.hasSuffix(".wav") }
        XCTAssertEqual(contents, [])
    }

    func testDeleteRemovesRowAndFile() throws {
        let base = tempDir()
        let bank = VoiceBank(baseDirectory: base)
        let saved = try XCTUnwrap(bank.bankIfEligible(
            sourceWavURL: try makeWav(seconds: 1.5, in: tempDir()),
            transcript: "delete me please now", intent: "dictation", appBundleId: nil
        ))
        let url = bank.audioURL(for: saved)
        bank.delete(id: saved.id)
        XCTAssertEqual(bank.allSamples().count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDeleteAllEmptiesStoreAndDirectory() throws {
        let base = tempDir()
        let bank = VoiceBank(baseDirectory: base)
        _ = bank.bankIfEligible(
            sourceWavURL: try makeWav(seconds: 1.5, in: tempDir()),
            transcript: "first banked sentence", intent: "dictation", appBundleId: nil
        )
        _ = bank.bankIfEligible(
            sourceWavURL: try makeWav(seconds: 1.5, in: tempDir()),
            transcript: "second banked sentence", intent: "dictation", appBundleId: nil
        )
        XCTAssertEqual(bank.stats().count, 2)
        bank.deleteAll()
        XCTAssertEqual(bank.stats().count, 0)
        let wavs = try FileManager.default.contentsOfDirectory(atPath: bank.audioDirectory.path)
            .filter { $0.hasSuffix(".wav") }
        XCTAssertEqual(wavs, [])
    }
}
