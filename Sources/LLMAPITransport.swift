import Foundation

enum LLMAPITransport {
    private static let requestSession: URLSession = {
        makeEphemeralSession()
    }()

    private static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20
        // The resource timeout must exceed every per-request timeoutInterval callers
        // set (transcription uploads configure their own), or it silently caps them
        // and kills any transfer past 30s — long dictations and slow providers
        // (upstream freeflow issue #253).
        configuration.timeoutIntervalForResource = 600
        return URLSession(configuration: configuration)
    }

    static func data(
        for request: URLRequest
    ) async throws -> (Data, URLResponse) {
        try await requestSession.data(for: request)
    }

    static func upload(
        for request: URLRequest,
        from bodyData: Data
    ) async throws -> (Data, URLResponse) {
        // Use a fresh session for each upload so a bad reused connection cannot
        // poison subsequent transcription uploads.
        let session = makeEphemeralSession()
        defer { session.finishTasksAndInvalidate() }
        return try await session.upload(for: request, from: bodyData)
    }
}
