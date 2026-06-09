import Foundation

enum ElevenLabsError: LocalizedError {
    case missingKey
    case noSamples
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No ElevenLabs API key set. Enter your key in the Voice Clone tab."
        case .noSamples:
            return "No voice bank samples to upload. Dictate more to build your voice bank."
        case .http(let status, let body):
            return "ElevenLabs error (HTTP \(status)): \(body)"
        case .badResponse:
            return "ElevenLabs returned an unexpected response (no voice_id)."
        }
    }
}

struct ElevenLabsClient {
    var apiKey: String
    var baseURL: String = "https://api.elevenlabs.io"

    /// Uploads audio clips to ElevenLabs Instant Voice Cloning and returns the created voice_id.
    func createInstantVoiceClone(name: String, audioFileURLs: [URL]) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw ElevenLabsError.missingKey }
        guard !audioFileURLs.isEmpty else { throw ElevenLabsError.noSamples }

        guard let endpoint = URL(string: "\(baseURL)/v1/voices/add") else {
            throw ElevenLabsError.badResponse
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(trimmedKey, forHTTPHeaderField: "xi-api-key")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        let body = try makeMultipartBody(
            name: name,
            audioFileURLs: audioFileURLs,
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.data(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.badResponse
        }

        guard httpResponse.statusCode == 200 else {
            let bodyString = String(data: data, encoding: .utf8) ?? "(empty)"
            throw ElevenLabsError.http(httpResponse.statusCode, bodyString)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let voiceID = json["voice_id"] as? String,
            !voiceID.isEmpty
        else {
            throw ElevenLabsError.badResponse
        }

        return voiceID
    }

    /// Calls ElevenLabs text-to-speech and returns the raw MP3 Data.
    ///
    /// - Parameters:
    ///   - text: The text to synthesize.
    ///   - voiceID: The ElevenLabs voice ID (percent-encoded into the URL path).
    /// - Throws: `ElevenLabsError.missingKey` when the API key is empty,
    ///           `ElevenLabsError.badResponse` when the voiceID is empty or the
    ///           URL cannot be constructed, `ElevenLabsError.http` on non-200 responses.
    /// - Returns: Raw MP3 audio data.
    func synthesizeSpeech(text: String, voiceID: String) async throws -> Data {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw ElevenLabsError.missingKey }

        let trimmedVoiceID = voiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVoiceID.isEmpty else { throw ElevenLabsError.badResponse }

        let encodedVoiceID = trimmedVoiceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmedVoiceID
        guard let endpoint = URL(string: "\(baseURL)/v1/text-to-speech/\(encodedVoiceID)") else {
            throw ElevenLabsError.badResponse
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(trimmedKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let bodyPayload: [String: String] = ["text": text, "model_id": "eleven_multilingual_v2"]
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyPayload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.badResponse
        }

        guard httpResponse.statusCode == 200 else {
            let bodyString = String(data: data, encoding: .utf8) ?? "(empty)"
            throw ElevenLabsError.http(httpResponse.statusCode, bodyString)
        }

        return data
    }

    // MARK: - Private

    private func makeMultipartBody(name: String, audioFileURLs: [URL], boundary: String) throws -> Data {
        var body = Data()

        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        // name field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"name\"\r\n\r\n")
        append("\(name)\r\n")

        // remove_background_noise field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"remove_background_noise\"\r\n\r\n")
        append("true\r\n")

        // audio files
        for fileURL in audioFileURLs {
            let audioData = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"files\"; filename=\"\(fileName)\"\r\n")
            append("Content-Type: audio/wav\r\n\r\n")
            body.append(audioData)
            append("\r\n")
        }

        append("--\(boundary)--\r\n")
        return body
    }
}

// URLSession helper that accepts a pre-built body as Data (mirrors how TranscriptionService uses LLMAPITransport).
private extension URLSession {
    func data(for request: URLRequest, from body: Data) async throws -> (Data, URLResponse) {
        var mutableRequest = request
        mutableRequest.httpBody = body
        return try await self.data(for: mutableRequest)
    }
}
