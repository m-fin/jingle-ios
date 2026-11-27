import type { SoundId } from "./types";
import { bundledSoundFile, DEFAULT_WAKE_SOUND } from "./soundFiles";
import { safeTrackId } from "./catalog";

/** iOS notification sounds must be 30 seconds or shorter. This leaves a little room. */
export const WAKE_CLIP_SECONDS = 28;
export const FADE_IN_SECONDS = 1.25;
export const FADE_OUT_SECONDS = 2;

export function catalogAudioFilename(trackId: string): string | null {
  const id = safeTrackId(trackId);
  if (!id) return null;
  return `${id}.mp3`;
}

export function wakeClipFilename(trackId: string): string | null {
  const id = safeTrackId(trackId);
  if (!id) return null;
  return `catalog-${id}.caf`;
}

/** Sibling of the iOS Documents directory, where UNNotificationSound looks up custom files. */
export function librarySoundsUri(documentUri: string | null | undefined): string | null {
  if (!documentUri) return null;
  if (!/\/Documents\/?$/.test(documentUri)) return null;
  return documentUri.replace(/\/Documents\/?$/, "/Library/Sounds");
}

export function resolveNotificationSound(input: {
  sound: SoundId | "machine";
  catalogClip?: string | null;
  clipReady: boolean;
  platform: string;
}): string {
  if (input.sound === "machine") return bundledSoundFile("machine");
  const clip = input.catalogClip ?? null;
  const clipNameOk = clip != null && /^catalog-[a-z0-9][a-z0-9-]{0,79}\.caf$/.test(clip) && !clip.includes("sonicrift");
  if (input.platform === "ios" && input.clipReady && clipNameOk && clip) return clip;
  if (input.sound === "dawn" || input.sound === "bell" || input.sound === "pulse" || input.sound === "chime") {
    return bundledSoundFile(input.sound);
  }
  return bundledSoundFile(DEFAULT_WAKE_SOUND);
}

function mixDown(samples: Float32Array, channels: number, frames: number): Float32Array {
  const mono = new Float32Array(frames);
  const width = Math.max(1, channels);
  for (let frame = 0; frame < frames; frame += 1) {
    let sum = 0;
    for (let channel = 0; channel < width; channel += 1) sum += samples[frame * width + channel] ?? 0;
    mono[frame] = sum / width;
  }
  return mono;
}

function fadeGain(time: number, duration: number): number {
  const fadeIn = Math.min(FADE_IN_SECONDS, duration / 3);
  const fadeOut = Math.min(FADE_OUT_SECONDS, duration / 3);
  let gain = 1;
  if (fadeIn > 0 && time < fadeIn) gain = Math.sin((time / fadeIn) * (Math.PI / 2));
  if (fadeOut > 0 && time > duration - fadeOut) gain *= Math.sin(((duration - time) / fadeOut) * (Math.PI / 2));
  return gain;
}

export function renderWakeClip(samples: Float32Array, sampleRate: number, channels = 1): Uint8Array {
  if (!Number.isFinite(sampleRate) || sampleRate < 8000 || sampleRate > 96000) {
    throw new Error("unsupported sample rate");
  }
  const width = Math.max(1, Math.floor(channels));
  const available = Math.floor(samples.length / width);
  const frames = Math.min(available, Math.floor(WAKE_CLIP_SECONDS * sampleRate));
  if (frames <= 0) throw new Error("empty audio");
  const mono = mixDown(samples, width, frames);
  const duration = frames / sampleRate;
  const pcm = new Int16Array(frames);
  for (let frame = 0; frame < frames; frame += 1) {
    const gain = fadeGain(frame / sampleRate, duration);
    const scaled = Math.max(-1, Math.min(1, (mono[frame] ?? 0) * gain));
    pcm[frame] = Math.round(scaled * 32767);
  }
  return encodeCafPcm16(pcm, sampleRate);
}

function writeFourCC(view: DataView, offset: number, text: string): void {
  for (let index = 0; index < 4; index += 1) view.setUint8(offset + index, text.charCodeAt(index));
}

function writeUint64(view: DataView, offset: number, value: number): void {
  view.setUint32(offset, Math.floor(value / 0x100000000), false);
  view.setUint32(offset + 4, value >>> 0, false);
}

/** 16-bit little-endian mono PCM in a CAF container iOS can play as a notification sound. */
export function encodeCafPcm16(samples: Int16Array, sampleRate: number): Uint8Array {
  const dataBytes = samples.length * 2;
  const total = 8 + 12 + 32 + 12 + 4 + dataBytes;
  const buffer = new ArrayBuffer(total);
  const view = new DataView(buffer);
  writeFourCC(view, 0, "caff");
  view.setUint16(4, 1, false);
  view.setUint16(6, 0, false);
  writeFourCC(view, 8, "desc");
  writeUint64(view, 12, 32);
  view.setFloat64(20, sampleRate, false);
  writeFourCC(view, 28, "lpcm");
  view.setUint32(32, 2, false);
  view.setUint32(36, 2, false);
  view.setUint32(40, 1, false);
  view.setUint32(44, 1, false);
  view.setUint32(48, 16, false);
  writeFourCC(view, 52, "data");
  writeUint64(view, 56, 4 + dataBytes);
  view.setUint32(64, 0, false);
  let offset = 68;
  for (let index = 0; index < samples.length; index += 1) {
    view.setInt16(offset, samples[index] ?? 0, true);
    offset += 2;
  }
  return new Uint8Array(buffer);
}

export function readCafPcm16(bytes: Uint8Array): { sampleRate: number; samples: Int16Array } {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const type = String.fromCharCode(bytes[0] ?? 0, bytes[1] ?? 0, bytes[2] ?? 0, bytes[3] ?? 0);
  if (type !== "caff") throw new Error("not a caf file");
  const sampleRate = view.getFloat64(20, false);
  const format = String.fromCharCode(bytes[28] ?? 0, bytes[29] ?? 0, bytes[30] ?? 0, bytes[31] ?? 0);
  if (format !== "lpcm") throw new Error("not pcm");
  const dataBytes = bytes.byteLength - 68;
  const samples = new Int16Array(Math.floor(dataBytes / 2));
  for (let index = 0; index < samples.length; index += 1) samples[index] = view.getInt16(68 + index * 2, true);
  return { sampleRate, samples };
}
