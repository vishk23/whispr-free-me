import Foundation

/// Minimal parser/writer for the recorder's mono PCM16 WAV format, shared by
/// `WAVEnergyProbe` (reads) and `TrailingSilenceTrimmer` (rewrites).
struct WAVFile {
    let samples: [Int16]
    let sampleRate: Double

    init?(data: Data) {
        guard data.count >= 44,
              data.subdata(in: 0..<4) == Data("RIFF".utf8),
              data.subdata(in: 8..<12) == Data("WAVE".utf8) else { return nil }

        var sampleRate: Double?
        var samples: [Int16]?
        var offset = 12
        while offset + 8 <= data.count {
            let chunkID = data.subdata(in: offset..<offset + 4)
            let chunkSize = Int(Self.readUInt32(data, at: offset + 4))
            let body = offset + 8
            guard chunkSize >= 0, body + chunkSize <= data.count else { return nil }
            if chunkID == Data("fmt ".utf8) {
                guard chunkSize >= 16 else { return nil }
                let format = Self.readUInt16(data, at: body)
                let channels = Self.readUInt16(data, at: body + 2)
                let bitsPerSample = Self.readUInt16(data, at: body + 14)
                guard format == 1, channels == 1, bitsPerSample == 16 else { return nil }
                sampleRate = Double(Self.readUInt32(data, at: body + 4))
            } else if chunkID == Data("data".utf8) {
                let count = chunkSize / 2
                samples = data.subdata(in: body..<body + count * 2).withUnsafeBytes { raw in
                    Array(raw.bindMemory(to: Int16.self)).map(Int16.init(littleEndian:))
                }
            }
            // Chunks are word-aligned: odd-sized chunks carry a pad byte.
            offset = body + chunkSize + (chunkSize % 2)
        }

        guard let sampleRate, sampleRate > 0, let samples else { return nil }
        self.sampleRate = sampleRate
        self.samples = samples
    }

    /// Canonical 44-byte-header mono PCM16 WAV bytes.
    static func pcm16MonoData(samples: [Int16], sampleRate: Double) -> Data {
        var data = Data(capacity: 44 + samples.count * 2)
        let byteCount = UInt32(samples.count * 2)
        let rate = UInt32(sampleRate)
        func append(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append(36 + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
        append(UInt16(1))        // PCM
        append(UInt16(1))        // mono
        append(rate)
        append(rate * 2)         // byte rate
        append(UInt16(2))        // block align
        append(UInt16(16))       // bits per sample
        data.append(contentsOf: Array("data".utf8)); append(byteCount)
        for s in samples { withUnsafeBytes(of: s.littleEndian) { data.append(contentsOf: $0) } }
        return data
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }
}
