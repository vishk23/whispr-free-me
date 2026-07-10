import Foundation
import Transcription

// MARK: - Configuration

guard let apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"], !apiKey.isEmpty else {
    fputs("Error: GROQ_API_KEY environment variable is not set or empty.\n", stderr)
    fputs("Usage: GROQ_API_KEY=<key> swift run replay [audio-directory]\n", stderr)
    exit(1)
}

let audioDir: URL = {
    if CommandLine.arguments.count > 1 {
        return URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    }
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home
        .appendingPathComponent("Library/Application Support/Whispr Free Me Dev/VoiceBank")
}()

let model = ProcessInfo.processInfo.environment["REPLAY_MODEL"] ?? "whisper-large-v3-turbo"
let baseURL = ProcessInfo.processInfo.environment["GROQ_BASE_URL"] ?? "https://api.groq.com/openai/v1"

// MARK: - WAV discovery

let fm = FileManager.default
guard fm.fileExists(atPath: audioDir.path) else {
    print("Audio directory not found: \(audioDir.path)")
    exit(0)
}

let contents = (try? fm.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil)) ?? []
let wavFiles = contents
    .filter { $0.pathExtension.lowercased() == "wav" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

guard !wavFiles.isEmpty else {
    print("No .wav files found in \(audioDir.path)")
    exit(0)
}

print("Found \(wavFiles.count) WAV file(s) in \(audioDir.path)")
print(String(repeating: "-", count: 60))

// MARK: - Multipart body builder

private func buildMultipartBody(boundary: String, wavURL: URL, model: String) throws -> Data {
    let wavData = try Data(contentsOf: wavURL)
    var body = Data()

    func append(_ string: String) {
        if let data = string.data(using: .utf8) { body.append(data) }
    }

    // model field
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    append("\(model)\r\n")

    // response_format field
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
    append("verbose_json\r\n")

    // temperature field
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n")
    append("0\r\n")

    // file field
    let filename = wavURL.lastPathComponent
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
    append("Content-Type: audio/wav\r\n\r\n")
    body.append(wavData)
    append("\r\n")

    // closing boundary
    append("--\(boundary)--\r\n")
    return body
}

// MARK: - Synchronous transcription

private struct TranscriptionResponse: Decodable {
    struct Segment: Decodable {
        let text: String
        let no_speech_prob: Double?
        let start: Double?
        let end: Double?
    }
    let text: String
    let segments: [Segment]?
}

private func transcribe(wavURL: URL, apiKey: String, model: String, baseURL: String) -> Result<(rawText: String, segments: [WhisperSegment]), Error> {
    let boundary = "Boundary-\(UUID().uuidString)"
    let endpoint = URL(string: "\(baseURL)/audio/transcriptions")!

    var request = URLRequest(url: endpoint, timeoutInterval: 60)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    do {
        request.httpBody = try buildMultipartBody(boundary: boundary, wavURL: wavURL, model: model)
    } catch {
        return .failure(error)
    }

    var resultData: Data?
    var resultResponse: URLResponse?
    var resultError: Error?

    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, response, error in
        resultData = data
        resultResponse = response
        resultError = error
        semaphore.signal()
    }.resume()
    semaphore.wait()

    if let error = resultError {
        return .failure(error)
    }

    guard let data = resultData else {
        return .failure(NSError(domain: "replay", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
    }

    if let http = resultResponse as? HTTPURLResponse, http.statusCode != 200 {
        let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
        return .failure(NSError(domain: "replay", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"]))
    }

    do {
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        let segments = (decoded.segments ?? []).map {
            WhisperSegment(text: $0.text, noSpeechProb: $0.no_speech_prob, start: $0.start, end: $0.end)
        }
        return .success((rawText: decoded.text, segments: segments))
    } catch {
        return .failure(error)
    }
}

// MARK: - Main loop

var strippedCount = 0

for wavURL in wavFiles {
    let filename = wavURL.lastPathComponent
    print("\n[\(filename)]")

    switch transcribe(wavURL: wavURL, apiKey: apiKey, model: model, baseURL: baseURL) {
    case .failure(let error):
        print("  ERROR: \(error.localizedDescription)")

    case .success(let result):
        let rawText = result.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let probe = WAVEnergyProbe(contentsOf: wavURL)
        let cleaned = HallucinationFilter.strip(
            text: result.rawText,
            segments: result.segments,
            windowRMS: probe.map { probe in { probe.rms(start: $0, end: $1) } }
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        print("  raw: \(rawText)")
        if cleaned != rawText {
            print("  STRIPPED -> \(cleaned)")
            strippedCount += 1
        } else {
            print("  clean (no change)")
        }
    }
}

print("\n" + String(repeating: "-", count: 60))
print("Summary: \(wavFiles.count) file(s), \(strippedCount) had trailing hallucinations stripped.")
