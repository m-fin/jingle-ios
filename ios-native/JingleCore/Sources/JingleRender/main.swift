import Foundation
import JingleCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Sounds")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for tone in WakeTone.allCases {
    let ramp = tone == .jingleBells ? 2.5 : 2.0
    let seconds = tone == .jingleBells ? 24.0 : 10.0
    let rate = 22_050.0
    let source = ToneSampleSource(tone: tone, sampleRate: rate, rampSeconds: ramp)
    let frames = Int(seconds * rate)
    var samples = source.render(frames: frames)
    let peak = samples.map { abs($0) }.max() ?? 1
    if peak > 0.0001 {
        let scale = Float(0.8 / peak)
        samples = samples.map { $0 * scale }
    }
    let url = output.appendingPathComponent(tone.notificationSoundName)
    try writeWAV(samples: samples, sampleRate: Int(rate), to: url)
    print("wrote \(url.path)")
}

func writeWAV(samples: [Float], sampleRate: Int, to url: URL) throws {
    let dataSize = samples.count * 2
    var data = Data()
    data.append(contentsOf: [UInt8]("RIFF".utf8))
    data.append(uint32(36 + UInt32(dataSize)))
    data.append(contentsOf: [UInt8]("WAVE".utf8))
    data.append(contentsOf: [UInt8]("fmt ".utf8))
    data.append(uint32(16))
    data.append(uint16(1))
    data.append(uint16(1))
    data.append(uint32(UInt32(sampleRate)))
    data.append(uint32(UInt32(sampleRate * 2)))
    data.append(uint16(2))
    data.append(uint16(16))
    data.append(contentsOf: [UInt8]("data".utf8))
    data.append(uint32(UInt32(dataSize)))
    for sample in samples {
        let clamped = max(-1, min(1, sample))
        var value = Int16(clamped * 32767).littleEndian
        data.append(Data(bytes: &value, count: 2))
    }
    try data.write(to: url)
}

func uint16(_ value: UInt16) -> Data {
    var little = value.littleEndian
    return Data(bytes: &little, count: 2)
}

func uint32(_ value: UInt32) -> Data {
    var little = value.littleEndian
    return Data(bytes: &little, count: 4)
}
