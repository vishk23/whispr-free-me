// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceBank",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "VoiceBank", path: "Sources/VoiceBank"),
        .testTarget(
            name: "VoiceBankTests",
            dependencies: ["VoiceBank"],
            path: "Tests/VoiceBankTests"
        ),
        .target(name: "Transcription", path: "Sources/Transcription"),
        .testTarget(
            name: "TranscriptionTests",
            dependencies: ["Transcription"],
            path: "Tests/TranscriptionTests"
        ),
    ]
)
