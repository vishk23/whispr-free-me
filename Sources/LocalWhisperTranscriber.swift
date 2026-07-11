import Foundation
import os.log

private let localWhisperLog = OSLog(subsystem: "com.vishk23.rhapsode", category: "LocalWhisper")

/// Offline transcription fallback: runs the brew-installed whisper-cli against the
/// locally cached large-v3-turbo model when the cloud provider is unreachable.
/// Benchmarked at ~1.4s/clip on M4 with 96.6% agreement vs Groq
/// (docs/evals/2026-07-10-local-transcription-eval.md).
enum LocalWhisperTranscriber {
    static let modelFileName = "ggml-large-v3-turbo-q5_0.bin"
    private static let processTimeoutSeconds: TimeInterval = 45

    static var modelURL: URL {
        AppState.appSupportBaseDirectory()
            .appendingPathComponent("WhisperModels")
            .appendingPathComponent(modelFileName)
    }

    static var binaryURL: URL? {
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    static var isAvailable: Bool {
        binaryURL != nil && FileManager.default.fileExists(atPath: modelURL.path)
    }

    static func transcribe(
        fileURL: URL,
        language: String?,
        vocabularyTerms: [String]
    ) async throws -> String {
        guard let binary = binaryURL else {
            throw TranscriptionError.transcriptionFailed("whisper-cli not installed")
        }
        let outputBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("whispr-local-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputBase.appendingPathExtension("json")) }

        var arguments = [
            "-m", modelURL.path,
            "-f", fileURL.path,
            "--output-json",
            "--output-file", outputBase.path,
            "--language", language ?? "auto"
        ]
        if !vocabularyTerms.isEmpty {
            arguments += ["--prompt", vocabularyTerms.joined(separator: ", ")]
        }

        let start = CFAbsoluteTimeGetCurrent()
        try await run(binary: binary, arguments: arguments)

        let jsonURL = outputBase.appendingPathExtension("json")
        guard let data = try? Data(contentsOf: jsonURL),
              let output = LocalWhisperOutput.parse(data) else {
            throw TranscriptionError.transcriptionFailed("Local transcription produced no output")
        }

        // Same post-filters as the cloud path: energy-evidence hallucination strip
        // (local output has no no_speech_prob, so audio evidence carries it) and the
        // dictionary-echo guard for the injected vocabulary prompt.
        let probe = (try? Data(contentsOf: fileURL)).flatMap { WAVEnergyProbe(data: $0) }
        var cleaned = HallucinationFilter.strip(
            text: output.text,
            segments: output.segments,
            windowRMS: probe.map { probe in { probe.rms(start: $0, end: $1) } }
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = DictionaryEchoGuard.stripTrailingPromptEcho(
            transcript: cleaned, vocabulary: vocabularyTerms
        )
        if DictionaryEchoGuard.isEcho(transcript: cleaned, vocabulary: vocabularyTerms) {
            cleaned = ""
        }
        os_log(
            .info, log: localWhisperLog,
            "local fallback transcribed %{public}@ in %.2fs (%d chars)",
            fileURL.lastPathComponent, CFAbsoluteTimeGetCurrent() - start, cleaned.count
        )
        return cleaned
    }

    private static func run(binary: URL, arguments: [String]) async throws {
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        // Kill the CLI if the enclosing task is cancelled (e.g. the cloud race was
        // won after the local hedge started) so it doesn't burn CPU to completion.
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let timeout = DispatchWorkItem { process.terminate() }
                process.terminationHandler = { finished in
                    timeout.cancel()
                    if finished.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed(
                            "whisper-cli exited with status \(finished.terminationStatus)"
                        ))
                    }
                }
                do {
                    try process.run()
                    DispatchQueue.global().asyncAfter(deadline: .now() + processTimeoutSeconds, execute: timeout)
                } catch {
                    timeout.cancel()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}
