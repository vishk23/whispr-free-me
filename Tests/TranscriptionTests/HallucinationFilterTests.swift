import XCTest
@testable import Transcription

final class HallucinationFilterTests: XCTestCase {

    // MARK: - trailing hallucination after real speech

    func testTrailingOkayHighProbIsStripped() {
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Hello world", noSpeechProb: 0.01),
            WhisperSegment(text: " Okay.", noSpeechProb: 0.6),
        ]
        let result = HallucinationFilter.strip(text: "Hello world Okay.", segments: segments)
        XCTAssertEqual(result, "Hello world")
    }

    func testTrailingOkayLowProbIsKept() {
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Hello world", noSpeechProb: 0.01),
            WhisperSegment(text: " Okay.", noSpeechProb: 0.02),
        ]
        let result = HallucinationFilter.strip(text: "Hello world Okay.", segments: segments)
        XCTAssertEqual(result, "Hello world Okay.")
    }

    // MARK: - single segment cases

    func testSingleSegmentOkayHighProbBecomesEmpty() {
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Okay.", noSpeechProb: 0.6),
        ]
        let result = HallucinationFilter.strip(text: "Okay.", segments: segments)
        XCTAssertEqual(result, "")
    }

    // MARK: - existing behavior preserved

    func testTrailingThankYouHighProbIsStripped() {
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Please send the report", noSpeechProb: 0.02),
            WhisperSegment(text: " Thank you.", noSpeechProb: 0.5),
        ]
        let result = HallucinationFilter.strip(text: "Please send the report Thank you.", segments: segments)
        XCTAssertEqual(result, "Please send the report")
    }

    // MARK: - normal segment not a phrase

    func testNormalFinalSegmentLowProbIsUnchanged() {
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Hello world", noSpeechProb: 0.01),
            WhisperSegment(text: " nice to meet you", noSpeechProb: 0.01),
        ]
        let result = HallucinationFilter.strip(text: "Hello world nice to meet you", segments: segments)
        XCTAssertEqual(result, "Hello world nice to meet you")
    }

    // MARK: - two consecutive trailing hallucinations

    func testTwoTrailingHallucinationsStripped() {
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Please review this", noSpeechProb: 0.01),
            WhisperSegment(text: " Okay.", noSpeechProb: 0.7),
            WhisperSegment(text: " Thank you.", noSpeechProb: 0.8),
        ]
        let result = HallucinationFilter.strip(text: "Please review this Okay. Thank you.", segments: segments)
        XCTAssertEqual(result, "Please review this")
    }

    // MARK: - conservative: no segments → unchanged

    func testEmptySegmentsReturnsTextUnchanged() {
        let result = HallucinationFilter.strip(text: "Okay.", segments: [])
        XCTAssertEqual(result, "Okay.")
    }

    // MARK: - short isolated trailing filler (the real Whisper pattern: no_speech_prob 0)

    func testTrailingShortOkaySegmentLowProbIsStripped() {
        // Real-world capture: Whisper appends " Okay." as a *confident* (no_speech_prob 0)
        // but short (0.3s), isolated trailing segment after the speaker stops.
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "we can adjust the modes.", noSpeechProb: 0.0, start: 0, end: 22.7),
            WhisperSegment(text: " Okay.", noSpeechProb: 0.0, start: 22.7, end: 23.0),
        ]
        let result = HallucinationFilter.strip(text: "we can adjust the modes. Okay.", segments: segments)
        XCTAssertEqual(result, "we can adjust the modes.")
    }

    func testTrailingShortThankYouLowProbIsKept() {
        // A deliberate short "Thank you." sign-off must survive: it's a silence-only phrase,
        // so the short-trailing heuristic does NOT apply to it.
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Best regards", noSpeechProb: 0.0, start: 0, end: 1.0),
            WhisperSegment(text: " Thank you.", noSpeechProb: 0.0, start: 1.0, end: 1.7),
        ]
        let result = HallucinationFilter.strip(text: "Best regards Thank you.", segments: segments)
        XCTAssertEqual(result, "Best regards Thank you.")
    }

    func testLongTrailingOkaySegmentLowProbIsKept() {
        // A long (2s) low-silence "Okay." segment isn't the short-filler signature, so it stays.
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Hello world", noSpeechProb: 0.0, start: 0, end: 2.0),
            WhisperSegment(text: " Okay.", noSpeechProb: 0.0, start: 2.0, end: 4.0),
        ]
        let result = HallucinationFilter.strip(text: "Hello world Okay.", segments: segments)
        XCTAssertEqual(result, "Hello world Okay.")
    }

    // MARK: - energy evidence: confident trailing "Thank you." over silent audio

    func testConfidentTrailingThankYouOverSilentAudioIsStripped() {
        // The real-world signature (history entry 839): Whisper appends " Thank you." as its
        // own confident (no_speech_prob 0.0) segment, but the recorded audio in that window
        // is silence — the speaker had already stopped. With energy evidence, it strips.
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Because, yeah.", noSpeechProb: 0.0, start: 0, end: 5.0),
            WhisperSegment(text: " Thank you.", noSpeechProb: 0.0, start: 5.0, end: 5.8),
        ]
        let result = HallucinationFilter.strip(
            text: "Because, yeah. Thank you.",
            segments: segments,
            windowRMS: { start, _ in start >= 5.0 ? 0.001 : 0.08 }
        )
        XCTAssertEqual(result, "Because, yeah.")
    }

    func testTrailingThankYouWithVoiceEnergyIsKept() {
        // A deliberately spoken "Thank you." sign-off has real voice energy in its window.
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Best regards", noSpeechProb: 0.0, start: 0, end: 1.0),
            WhisperSegment(text: " Thank you.", noSpeechProb: 0.0, start: 1.0, end: 1.7),
        ]
        let result = HallucinationFilter.strip(
            text: "Best regards Thank you.",
            segments: segments,
            windowRMS: { _, _ in 0.05 }
        )
        XCTAssertEqual(result, "Best regards Thank you.")
    }

    func testNonFillerTrailingSegmentOverSilentAudioIsKept() {
        // Energy evidence never strips text that isn't a known filler phrase, even if the
        // window reads silent (mis-timestamped real speech must survive).
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Hello world", noSpeechProb: 0.0, start: 0, end: 2.0),
            WhisperSegment(text: " see you at the office", noSpeechProb: 0.0, start: 2.0, end: 3.0),
        ]
        let result = HallucinationFilter.strip(
            text: "Hello world see you at the office",
            segments: segments,
            windowRMS: { _, _ in 0.0001 }
        )
        XCTAssertEqual(result, "Hello world see you at the office")
    }

    func testThankYouWithoutTimestampsFallsBackToSilenceOnlyBehavior() {
        // No start/end on the segment → the window can't be probed → the conservative
        // silence-only rule applies and the sign-off survives.
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Best regards", noSpeechProb: 0.0),
            WhisperSegment(text: " Thank you.", noSpeechProb: 0.0),
        ]
        let result = HallucinationFilter.strip(
            text: "Best regards Thank you.",
            segments: segments,
            windowRMS: { _, _ in 0.0001 }
        )
        XCTAssertEqual(result, "Best regards Thank you.")
    }

    func testCascadeStripsFillerRunOverSilentTail() {
        // Multiple trailing fillers over a silent tail all strip; real speech is preserved.
        let segments: [WhisperSegment] = [
            WhisperSegment(text: "Ship it today.", noSpeechProb: 0.0, start: 0, end: 3.0),
            WhisperSegment(text: " Okay.", noSpeechProb: 0.0, start: 3.0, end: 3.4),
            WhisperSegment(text: " Thank you.", noSpeechProb: 0.0, start: 3.4, end: 4.1),
        ]
        let result = HallucinationFilter.strip(
            text: "Ship it today. Okay. Thank you.",
            segments: segments,
            windowRMS: { start, _ in start >= 3.0 ? 0.0008 : 0.09 }
        )
        XCTAssertEqual(result, "Ship it today.")
    }
}
