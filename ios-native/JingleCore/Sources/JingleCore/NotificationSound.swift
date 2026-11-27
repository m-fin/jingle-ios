import Foundation

/// How a bundled file is offered to `UNNotificationSound` and AlarmKit.
public struct BundledSoundFile: Equatable, Sendable {
    public var fileName: String
    /// `nil` means the app bundle root. A subdirectory is not a valid notification sound.
    public var subdirectory: String?

    public init(fileName: String, subdirectory: String? = nil) {
        self.fileName = fileName
        self.subdirectory = subdirectory
    }
}

public enum NotificationSoundChoice: Equatable, Sendable {
    /// Exact bundle-root filename, including the extension.
    case custom(String)
    /// The file is missing, mistyped, or not a sound the system alert server can play.
    case systemDefault
}

public enum NotificationSoundEncoding: Equatable, Sendable {
    case linearPCM(littleEndian: Bool, bitsPerChannel: Int, floatingPoint: Bool)
    case ima4
    case aac
    case unsupported
}

public struct NotificationSoundHeader: Equatable, Sendable {
    public var duration: TimeInterval
    public var sampleRate: Double
    public var channels: Int
    public var encoding: NotificationSoundEncoding
    /// Peak absolute sample in the opening window. Linear PCM only; otherwise 0.
    public var openingPeak: Int

    public init(
        duration: TimeInterval,
        sampleRate: Double,
        channels: Int,
        encoding: NotificationSoundEncoding,
        openingPeak: Int
    ) {
        self.duration = duration
        self.sampleRate = sampleRate
        self.channels = channels
        self.encoding = encoding
        self.openingPeak = openingPeak
    }

    /// True when the system sound facility can play this file as an alert.
    ///
    /// The alert server wants a short little-endian 16-bit integer CAF (or IMA4 / AAC)
    /// at the bundle root. A big-endian payload tagged as little-endian still "exists",
    /// but it decodes as silence, and iOS will not fall back to the default tone.
    public var playsAsNotificationSound: Bool {
        guard duration > 0, duration <= NotificationSoundLookup.maximumDuration else { return false }
        switch encoding {
        case .linearPCM(let littleEndian, let bits, let floatingPoint):
            guard littleEndian, !floatingPoint, bits == 16, channels == 1 else { return false }
            return openingPeak >= NotificationSoundLookup.minimumOpeningPeak
        case .ima4, .aac:
            return channels >= 1 && sampleRate > 0
        case .unsupported:
            return false
        }
    }
}

public enum NotificationSoundLookup {
    /// Apple plays the default tone when a custom alert sound is longer than this.
    public static let maximumDuration: TimeInterval = 30
    /// Opening window used to reject a file that decodes as silence.
    public static let openingWindow: TimeInterval = 3
    /// A swapped-endian 16-bit file stays under a few hundred. A real wake tone does not.
    public static let minimumOpeningPeak = 1_000

    /// Case-sensitive bundle-root lookup. Anything else becomes the system default tone
    /// so a scheduled alarm cannot attach a custom sound that plays as silence.
    public static func resolve(
        requestedFileName: String,
        bundled: [BundledSoundFile],
        header: NotificationSoundHeader?
    ) -> NotificationSoundChoice {
        guard isBundleRootFileName(requestedFileName) else { return .systemDefault }
        let atRoot = bundled.contains { $0.fileName == requestedFileName && $0.subdirectory == nil }
        guard atRoot, let header, header.playsAsNotificationSound else { return .systemDefault }
        return .custom(requestedFileName)
    }

    public static func isBundleRootFileName(_ name: String) -> Bool {
        guard !name.isEmpty, name.contains("."), !name.hasPrefix(".") else { return false }
        return !name.contains("/") && !name.contains("\\")
    }
}

public enum CAFNotificationSound {
    public static func header(of data: Data) -> NotificationSoundHeader? {
        guard data.count >= 44 else { return nil }
        guard readASCII(data, 0, 4) == "caff" else { return nil }
        var offset = 8
        var sampleRate = 0.0
        var channels = 0
        var bits = 0
        var bytesPerPacket = 0
        var framesPerPacket = 1
        var encoding: NotificationSoundEncoding?
        var littleEndian = false
        var dataPayload = 0
        var dataChunkSize = 0

        while offset + 12 <= data.count {
            let type = readASCII(data, offset, 4)
            let size = readUInt64(data, offset + 4)
            let payload = offset + 12
            guard size <= UInt64(Int.max), payload <= data.count else { return nil }
            let sizeInt = Int(size)
            if type == "desc" {
                guard sizeInt >= 32, payload + 32 <= data.count else { return nil }
                sampleRate = readDouble(data, payload)
                let format = readUInt32(data, payload + 8)
                let flags = readUInt32(data, payload + 12)
                bytesPerPacket = Int(readUInt32(data, payload + 16))
                framesPerPacket = Int(readUInt32(data, payload + 20))
                channels = Int(readUInt32(data, payload + 24))
                bits = Int(readUInt32(data, payload + 28))
                littleEndian = (flags & 0x2) != 0
                let floating = (flags & 0x1) != 0
                switch format {
                case 0x6C70_636D: // lpcm
                    encoding = .linearPCM(littleEndian: littleEndian, bitsPerChannel: bits, floatingPoint: floating)
                case 0x696D_6134: // ima4
                    encoding = .ima4
                case 0x6161_6320, 0x6161_6365, 0x6161_6366, 0x6161_6367: // aac , aace, aacf, aacg
                    encoding = .aac
                default:
                    encoding = .unsupported
                }
            } else if type == "data" {
                dataPayload = payload
                dataChunkSize = sizeInt
                break
            }
            let next = payload + sizeInt
            guard next > offset else { return nil }
            offset = next
        }

        guard let encoding, sampleRate > 0, bytesPerPacket > 0, dataChunkSize >= 4 else { return nil }
        let audioBytes = dataChunkSize - 4
        let duration: TimeInterval
        if case .linearPCM = encoding {
            duration = Double(audioBytes) / Double(bytesPerPacket) / sampleRate
        } else {
            let packets = Double(audioBytes) / Double(bytesPerPacket)
            duration = packets * Double(max(framesPerPacket, 1)) / sampleRate
        }
        let peak: Int
        if case .linearPCM = encoding, bits == 16, channels > 0 {
            let available = min(audioBytes, max(0, data.count - (dataPayload + 4)))
            peak = openingPeak(
                data: data,
                audioStart: dataPayload + 4,
                audioBytes: available,
                channels: channels,
                littleEndian: littleEndian,
                sampleRate: sampleRate
            )
        } else {
            peak = 0
        }
        return NotificationSoundHeader(
            duration: duration,
            sampleRate: sampleRate,
            channels: channels,
            encoding: encoding,
            openingPeak: peak
        )
    }

    private static func openingPeak(
        data: Data,
        audioStart: Int,
        audioBytes: Int,
        channels: Int,
        littleEndian: Bool,
        sampleRate: Double
    ) -> Int {
        let bytesPerFrame = channels * 2
        guard bytesPerFrame > 0, audioBytes >= bytesPerFrame, audioStart >= 0 else { return 0 }
        let framesAvailable = audioBytes / bytesPerFrame
        let windowFrames = min(framesAvailable, Int(sampleRate * NotificationSoundLookup.openingWindow))
        var peak = 0
        let end = audioStart + windowFrames * bytesPerFrame
        var index = audioStart
        while index + 1 < end && index + 1 < data.count {
            let sample = readInt16(data, index, littleEndian: littleEndian)
            peak = max(peak, abs(Int(sample)))
            index += 2
        }
        return peak
    }

    private static func readASCII(_ data: Data, _ offset: Int, _ count: Int) -> String {
        let slice = data[offset..<(offset + count)]
        return String(bytes: slice, encoding: .ascii) ?? ""
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        var value: UInt32 = 0
        for byte in data[offset..<(offset + 4)] {
            value = (value << 8) | UInt32(byte)
        }
        return value
    }

    private static func readUInt64(_ data: Data, _ offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for byte in data[offset..<(offset + 8)] {
            value = (value << 8) | UInt64(byte)
        }
        return value
    }

    private static func readDouble(_ data: Data, _ offset: Int) -> Double {
        let bits = readUInt64(data, offset)
        return Double(bitPattern: bits)
    }

    private static func readInt16(_ data: Data, _ offset: Int, littleEndian: Bool) -> Int16 {
        let first = UInt16(data[offset])
        let second = UInt16(data[offset + 1])
        let bits = littleEndian ? (first | (second << 8)) : ((first << 8) | second)
        return Int16(bitPattern: bits)
    }
}
