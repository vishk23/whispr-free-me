import XCTest
@testable import Transcription

final class TrailingSilenceTrimmerTests: XCTestCase {

    private func makeWAV(samples: [Int16], sampleRate: UInt32 = 16000) -> Data {
        var data = Data()
        let byteCount = UInt32(samples.count * 2)
        func append(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append(36 + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
        append(UInt16(1)); append(UInt16(1)); append(sampleRate)
        append(sampleRate * 2); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(byteCount)
        for s in samples { withUnsafeBytes(of: s.littleEndian) { data.append(contentsOf: $0) } }
        return data
    }

    private func voiced(seconds: Double) -> [Int16] {
        (0..<Int(seconds * 16000)).map { Int16($0 % 2 == 0 ? 3277 : -3277) }
    }

    private func silence(seconds: Double) -> [Int16] {
        [Int16](repeating: 0, count: Int(seconds * 16000))
    }

    func testLongTrailingSilenceIsTrimmedToHangover() throws {
        // 1s speech + 4s dead air → speech + ~1s hangover. The dead air Whisper
        // hallucinates on never reaches the API.
        let wav = makeWAV(samples: voiced(seconds: 1.0) + silence(seconds: 4.0))
        let trimmed = TrailingSilenceTrimmer.trim(wavData: wav)
        let probe = try XCTUnwrap(WAVEnergyProbe(data: trimmed))
        XCTAssertLessThan(trimmed.count, wav.count)
        // Speech survives intact...
        XCTAssertGreaterThan(probe.rms(start: 0.0, end: 1.0), HallucinationFilter.energySilenceFloor)
        // ...total duration is speech + hangover (~2s), well short of the original 5s.
        XCTAssertEqual(probe.rms(start: 2.5, end: 5.0), 0)
    }

    func testSpeechToTheEndIsUntouched() {
        let wav = makeWAV(samples: voiced(seconds: 2.0))
        XCTAssertEqual(TrailingSilenceTrimmer.trim(wavData: wav), wav)
    }

    func testShortTrailingSilenceIsNotWorthTrimming() {
        // Only ~0.5s of dead air beyond the hangover threshold — leave the file alone
        // rather than rewrite it for a marginal saving.
        let wav = makeWAV(samples: voiced(seconds: 1.0) + silence(seconds: 1.2))
        XCTAssertEqual(TrailingSilenceTrimmer.trim(wavData: wav), wav)
    }

    func testAllSilentClipIsUntouched() {
        // Nothing above the floor → conservative no-op; downstream guards own this case.
        let wav = makeWAV(samples: silence(seconds: 3.0))
        XCTAssertEqual(TrailingSilenceTrimmer.trim(wavData: wav), wav)
    }

    func testGarbageDataIsUntouched() {
        let garbage = Data([0x01, 0x02, 0x03, 0x04])
        XCTAssertEqual(TrailingSilenceTrimmer.trim(wavData: garbage), garbage)
    }

    func testTrimmedOutputIsAValidWAVWithConsistentHeader() throws {
        let wav = makeWAV(samples: voiced(seconds: 1.0) + silence(seconds: 4.0))
        let trimmed = TrailingSilenceTrimmer.trim(wavData: wav)
        // Re-parseable, and declared sizes match actual byte count.
        XCTAssertNotNil(WAVEnergyProbe(data: trimmed))
        let riffSize = trimmed.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(Int(riffSize) + 8, trimmed.count)
    }
}
