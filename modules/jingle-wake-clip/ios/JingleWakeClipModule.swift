import AVFoundation
import ExpoModulesCore

private enum WakeClipError: Error, LocalizedError {
  case noAudio
  case unreadable(String)
  case empty

  var errorDescription: String? {
    switch self {
    case .noAudio:
      return "That track has no audio."
    case .unreadable(let message):
      return message
    case .empty:
      return "The wake clip was empty."
    }
  }
}

enum JingleWakeClipExporter {
  static let clipSeconds = 28.0
  static let fadeInSeconds = 1.25
  static let fadeOutSeconds = 2.0
  static let sampleRate = 44_100.0

  static func export(inputPath: String, outputPath: String) async throws {
    let input = fileURL(inputPath)
    let output = fileURL(outputPath)
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: output.path) {
      try FileManager.default.removeItem(at: output)
    }

    let asset = AVURLAsset(url: input, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    let tracks = try await asset.loadTracks(withMediaType: .audio)
    guard let track = tracks.first else { throw WakeClipError.noAudio }
    let duration = try await asset.load(.duration)
    let seconds = duration.seconds
    let clip = seconds.isFinite && seconds > 0 ? min(clipSeconds, seconds) : clipSeconds

    let reader = try AVAssetReader(asset: asset)
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    trackOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(trackOutput) else { throw WakeClipError.unreadable("Could not read audio.") }
    reader.add(trackOutput)
    reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: clip, preferredTimescale: 44_100))
    guard reader.startReading() else {
      throw WakeClipError.unreadable(reader.error?.localizedDescription ?? "Could not read audio.")
    }

    var pcm = Data()
    while let sample = trackOutput.copyNextSampleBuffer() {
      guard let buffer = CMSampleBufferGetDataBuffer(sample) else { continue }
      let length = CMBlockBufferGetDataLength(buffer)
      var chunk = Data(count: length)
      let copied = chunk.withUnsafeMutableBytes { raw -> OSStatus in
        guard let base = raw.baseAddress else { return -1 }
        return CMBlockBufferCopyDataBytes(buffer, atOffset: 0, dataLength: length, destination: base)
      }
      if copied == noErr {
        pcm.append(chunk)
      }
    }
    if reader.status == .failed {
      throw WakeClipError.unreadable(reader.error?.localizedDescription ?? "Could not read audio.")
    }

    var samples = pcm.withUnsafeBytes { raw -> [Int16] in
      let count = raw.count / MemoryLayout<Int16>.size
      guard let address = raw.baseAddress?.assumingMemoryBound(to: Int16.self) else { return [] }
      return Array(UnsafeBufferPointer(start: address, count: count))
    }
    guard !samples.isEmpty else { throw WakeClipError.empty }
    applyFade(&samples)

    guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true) else {
      throw WakeClipError.unreadable("Could not open the wake clip.")
    }
    let file = try AVAudioFile(forWriting: output, settings: format.settings, commonFormat: .pcmFormatInt16, interleaved: true)
    let frames = AVAudioFrameCount(samples.count)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let channel = buffer.int16ChannelData else {
      throw WakeClipError.empty
    }
    buffer.frameLength = frames
    samples.withUnsafeBufferPointer { pointer in
      guard let address = pointer.baseAddress else { return }
      channel[0].update(from: address, count: samples.count)
    }
    try file.write(from: buffer)
  }

  private static func applyFade(_ samples: inout [Int16]) {
    let frames = samples.count
    let duration = Double(frames) / sampleRate
    let fadeIn = min(fadeInSeconds, duration / 3)
    let fadeOut = min(fadeOutSeconds, duration / 3)
    for index in samples.indices {
      let time = Double(index) / sampleRate
      var gain = 1.0
      if fadeIn > 0, time < fadeIn {
        gain = sin((time / fadeIn) * .pi / 2)
      }
      if fadeOut > 0, time > duration - fadeOut {
        gain *= sin(((duration - time) / fadeOut) * .pi / 2)
      }
      let scaled = Double(samples[index]) * gain
      samples[index] = Int16(max(-32768, min(32767, scaled.rounded())))
    }
  }

  private static func fileURL(_ path: String) -> URL {
    if path.hasPrefix("file://"), let url = URL(string: path) {
      return url
    }
    return URL(fileURLWithPath: path)
  }
}

@ExpoModule("JingleWakeClip")
public final class JingleWakeClipModule: Module {
  @JS
  func exportWakeClip(input: String, output: String) async throws {
    try await JingleWakeClipExporter.export(inputPath: input, outputPath: output)
  }
}
