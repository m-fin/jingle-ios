import AV from "av";
import "mp3";

import { WAKE_CLIP_SECONDS, type PcmAudio } from "./wakeClip";

const DECODE_TIMEOUT_MS = 20_000;

/**
 * Decode the front of an MP3 into interleaved float samples.
 * The pure-JS decoder runs anywhere the app does, including a locked-down JS runtime.
 */
export function decodeMp3Clip(bytes: Uint8Array, maxSeconds = WAKE_CLIP_SECONDS): Promise<PcmAudio | null> {
  if (bytes.byteLength < 64) return Promise.resolve(null);
  return new Promise((resolve) => {
    let settled = false;
    const finish = (value: PcmAudio | null) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(value);
    };
    const timer = setTimeout(() => finish(null), DECODE_TIMEOUT_MS);
    try {
      const asset = AV.Asset.fromBuffer(bytes);
      asset.on("error", () => finish(null));
      asset.decodeToBuffer((buffer) => {
        const channels = asset.format?.channelsPerFrame ?? 0;
        const sampleRate = asset.format?.sampleRate ?? 0;
        if (channels < 1 || channels > 2 || sampleRate < 8000) {
          finish(null);
          return;
        }
        const frames = Math.floor(buffer.length / channels);
        const keep = Math.min(frames, Math.floor(maxSeconds * sampleRate));
        if (keep < sampleRate / 10) {
          finish(null);
          return;
        }
        finish({
          sampleRate,
          channels,
          samples: new Float32Array(buffer.subarray(0, keep * channels)),
        });
      });
    } catch {
      finish(null);
    }
  });
}
