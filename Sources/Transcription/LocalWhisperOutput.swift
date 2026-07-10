import Foundation

/// Parses whisper-cli's `--output-json` file into the same segment shape the cloud
/// path uses, so the hallucination filter and energy probe apply identically.
public struct LocalWhisperOutput {
    public let text: String
    public let segments: [WhisperSegment]

    public static func parse(_ data: Data) -> LocalWhisperOutput? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let transcription = json["transcription"] as? [[String: Any]],
              !transcription.isEmpty else { return nil }
        let segments = transcription.map { entry -> WhisperSegment in
            let offsets = entry["offsets"] as? [String: Any]
            let fromMS = (offsets?["from"] as? NSNumber)?.doubleValue
            let toMS = (offsets?["to"] as? NSNumber)?.doubleValue
            return WhisperSegment(
                text: entry["text"] as? String ?? "",
                noSpeechProb: (entry["no_speech_prob"] as? NSNumber)?.doubleValue,
                start: fromMS.map { $0 / 1000 },
                end: toMS.map { $0 / 1000 }
            )
        }
        return LocalWhisperOutput(text: segments.map(\.text).joined(), segments: segments)
    }
}
