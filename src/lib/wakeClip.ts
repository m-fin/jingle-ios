export const WAKE_CLIP_SECONDS = 28;
export const FADE_IN_SECONDS = 1.6;
export const FADE_OUT_SECONDS = 2.6;

export type PcmAudio = {
  sampleRate: number;
  channels: number;
  samples: Float32Array;
};

const CAF_LPCM_LITTLE_ENDIAN = 2;
const CHANNEL_MONO = 0x00640001;
const CHANNEL_STEREO = 0x00650002;

export function clipByteLength(totalBytes: number, durationSeconds: number, clipSeconds = WAKE_CLIP_SECONDS): number {
  if (!Number.isFinite(totalBytes) || totalBytes <= 0) return 0;
  if (!Number.isFinite(durationSeconds) || durationSeconds <= clipSeconds + 0.25) return Math.floor(totalBytes);
  const ratio = (clipSeconds + 1.25) / durationSeconds;
  return Math.min(Math.floor(totalBytes), Math.ceil(totalBytes * ratio) + 16384);
}

/** Equal-power edge fades. The middle of the clip stays at full level. */
export function frameGain(
  frameIndex: number,
  frameCount: number,
  sampleRate: number,
  fadeIn = FADE_IN_SECONDS,
  fadeOut = FADE_OUT_SECONDS,
): number {
  if (frameCount <= 1 || sampleRate <= 0) return 1;
  const duration = frameCount / sampleRate;
  const inSeconds = Math.min(fadeIn, duration * 0.35);
  const outSeconds = Math.min(fadeOut, duration * 0.45);
  const time = frameIndex / sampleRate;
  let gain = 1;
  if (inSeconds > 0 && time < inSeconds) {
    const position = time / inSeconds;
    gain = Math.min(gain, 0.5 - 0.5 * Math.cos(Math.PI * position));
  }
  if (outSeconds > 0 && time > duration - outSeconds) {
    const position = (duration - time) / outSeconds;
    gain = Math.min(gain, 0.5 - 0.5 * Math.cos(Math.PI * Math.max(0, position)));
  }
  return gain;
}

function peakOf(samples: Float32Array): number {
  let peak = 0;
  for (let index = 0; index < samples.length; index += 1) {
    const value = Math.abs(samples[index] ?? 0);
    if (value > peak) peak = value;
  }
  return peak;
}

function writeAscii(view: DataView, offset: number, text: string): void {
  for (let index = 0; index < text.length; index += 1) view.setUint8(offset + index, text.charCodeAt(index));
}

/**
 * 16-bit little-endian PCM in a CAF container.
 * iOS notification sounds accept this layout, and the clip stays under 30 seconds.
 */
export function renderWakeClip(pcm: PcmAudio, seconds = WAKE_CLIP_SECONDS): Uint8Array | null {
  const channels = pcm.channels === 2 ? 2 : pcm.channels === 1 ? 1 : 0;
  if (!channels || pcm.sampleRate < 8000 || pcm.sampleRate > 96000) return null;
  const available = Math.floor(pcm.samples.length / channels);
  const frames = Math.min(available, Math.floor(seconds * pcm.sampleRate));
  if (frames < pcm.sampleRate / 10) return null;

  const sliced = pcm.samples.subarray(0, frames * channels);
  const peak = peakOf(sliced);
  const makeup = peak > 0.0008 ? Math.min(0.9 / peak, 2.5) : 1;
  const pcmBytes = frames * channels * 2;
  const headerBytes = 8 + (12 + 32) + (12 + 12) + 12 + 4;
  const file = new Uint8Array(headerBytes + pcmBytes);
  const view = new DataView(file.buffer);
  let offset = 0;

  writeAscii(view, offset, "caff");
  view.setUint16(offset + 4, 1, false);
  view.setUint16(offset + 6, 0, false);
  offset += 8;

  writeAscii(view, offset, "desc");
  view.setBigInt64(offset + 4, 32n, false);
  view.setFloat64(offset + 12, pcm.sampleRate, false);
  writeAscii(view, offset + 20, "lpcm");
  view.setUint32(offset + 24, CAF_LPCM_LITTLE_ENDIAN, false);
  view.setUint32(offset + 28, channels * 2, false);
  view.setUint32(offset + 32, 1, false);
  view.setUint32(offset + 36, channels, false);
  view.setUint32(offset + 40, 16, false);
  offset += 12 + 32;

  writeAscii(view, offset, "chan");
  view.setBigInt64(offset + 4, 12n, false);
  view.setUint32(offset + 12, channels === 2 ? CHANNEL_STEREO : CHANNEL_MONO, false);
  view.setUint32(offset + 16, 0, false);
  view.setUint32(offset + 20, 0, false);
  offset += 12 + 12;

  writeAscii(view, offset, "data");
  view.setBigInt64(offset + 4, BigInt(4 + pcmBytes), false);
  view.setUint32(offset + 12, 0, false);
  offset += 12 + 4;

  for (let frame = 0; frame < frames; frame += 1) {
    const gain = frameGain(frame, frames, pcm.sampleRate) * makeup;
    for (let channel = 0; channel < channels; channel += 1) {
      const sample = (sliced[frame * channels + channel] ?? 0) * gain;
      const clamped = Math.max(-1, Math.min(1, sample));
      view.setInt16(offset, Math.round(clamped * 32767), true);
      offset += 2;
    }
  }
  return file;
}
