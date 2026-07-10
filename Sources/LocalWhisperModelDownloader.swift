import Foundation
import Combine

/// Downloads the quantized whisper model that powers the offline transcription
/// fallback, with progress, into Application Support/WhisperModels. Makes the
/// offline feature self-serve instead of a manual curl.
final class LocalWhisperModelDownloader: NSObject, ObservableObject {
    static let shared = LocalWhisperModelDownloader()

    static let modelDownloadURL = URL(
        string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin"
    )!
    static let approximateSizeMB = 547

    @Published private(set) var isDownloading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var modelInstalled: Bool

    private var session: URLSession?
    private var task: URLSessionDownloadTask?

    private override init() {
        modelInstalled = FileManager.default.fileExists(atPath: LocalWhisperTranscriber.modelURL.path)
        super.init()
    }

    func refresh() {
        modelInstalled = FileManager.default.fileExists(atPath: LocalWhisperTranscriber.modelURL.path)
    }

    func startDownload() {
        guard !isDownloading else { return }
        errorMessage = nil
        progress = 0
        isDownloading = true
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.downloadTask(with: Self.modelDownloadURL)
        self.task = task
        task.resume()
    }

    func cancelDownload() {
        task?.cancel()
        finish(error: nil, cancelled: true)
    }

    func deleteModel() {
        try? FileManager.default.removeItem(at: LocalWhisperTranscriber.modelURL)
        refresh()
    }

    private func finish(error: String?, cancelled: Bool = false) {
        DispatchQueue.main.async {
            self.isDownloading = false
            self.errorMessage = cancelled ? nil : error
            self.session?.finishTasksAndInvalidate()
            self.session = nil
            self.task = nil
            self.refresh()
        }
    }
}

extension LocalWhisperModelDownloader: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { self.progress = fraction }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let destination = LocalWhisperTranscriber.modelURL
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            finish(error: nil)
        } catch {
            finish(error: "Could not install model: \(error.localizedDescription)")
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, (error as NSError).code != NSURLErrorCancelled {
            finish(error: error.localizedDescription)
        }
    }
}
