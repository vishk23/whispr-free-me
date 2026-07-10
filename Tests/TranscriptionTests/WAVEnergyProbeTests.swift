import XCTest
@testable import Transcription

final class WAVEnergyProbeTests: XCTestCase {

    /// Canonical 44-byte-header PCM16 mono WAV, as AudioRecorder writes.
    private func makeWAV(samples: [Int16], sampleRate: UInt32 = 16000) -> Data {
        var data = Data()
        let byteCount = UInt32(samples.count * 2)
        func append(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append(36 + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
        append(UInt16(1))            // PCM
        append(UInt16(1))            // mono
        append(sampleRate)
        append(sampleRate * 2)       // byte rate
        append(UInt16(2))            // block align
        append(UInt16(16))           // bits per sample
        data.append(contentsOf: Array("data".utf8)); append(byteCount)
        for s in samples { withUnsafeBytes(of: s.littleEndian) { data.append(contentsOf: $0) } }
        return data
    }

    /// 0.0–0.5s: voice-level square wave (amplitude ~0.1); 0.5–1.0s: digital silence.
    private func makeHalfSpeechHalfSilenceWAV() -> Data {
        let voiced = (0..<8000).map { Int16($0 % 2 == 0 ? 3277 : -3277) }
        let silent = [Int16](repeating: 0, count: 8000)
        return makeWAV(samples: voiced + silent)
    }

    func testSpeechWindowHasEnergyAndSilentWindowDoesNot() throws {
        let probe = try XCTUnwrap(WAVEnergyProbe(data: makeHalfSpeechHalfSilenceWAV()))
        XCTAssertGreaterThan(probe.rms(start: 0.0, end: 0.5), HallucinationFilter.energySilenceFloor)
        XCTAssertLessThan(probe.rms(start: 0.5, end: 1.0), HallucinationFilter.energySilenceFloor)
    }

    func testWindowPastEndOfAudioReadsSilent() throws {
        let probe = try XCTUnwrap(WAVEnergyProbe(data: makeHalfSpeechHalfSilenceWAV()))
        // Whisper sometimes stamps hallucinated segments past the real audio; no audio
        // there means no voice there.
        XCTAssertEqual(probe.rms(start: 2.0, end: 3.0), 0)
    }

    func testWindowStraddlingSpeechAndSilenceClampsToRealSamples() throws {
        let probe = try XCTUnwrap(WAVEnergyProbe(data: makeHalfSpeechHalfSilenceWAV()))
        let straddle = probe.rms(start: 0.4, end: 0.6)
        XCTAssertGreaterThan(straddle, probe.rms(start: 0.5, end: 1.0))
        XCTAssertLessThan(straddle, probe.rms(start: 0.0, end: 0.5))
    }

    func testGarbageDataFailsInit() {
        XCTAssertNil(WAVEnergyProbe(data: Data([0x00, 0x01, 0x02, 0x03])))
        XCTAssertNil(WAVEnergyProbe(data: Data()))
    }

    func testStereoOrNonPCMDataFailsInit() {
        // Build a header claiming 2 channels; the probe only understands the recorder's
        // mono PCM16 output and must refuse rather than misread.
        var wav = makeWAV(samples: [0, 0, 0, 0])
        wav[22] = 2 // channel count LSB
        XCTAssertNil(WAVEnergyProbe(data: wav))
    }
}
