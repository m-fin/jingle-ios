import AsyncStorage from "@react-native-async-storage/async-storage";
import { Directory, File, Paths } from "expo-file-system";
import { Platform } from "react-native";

import seedCatalog from "../../assets/catalog.seed.json";
import { exportWakeClip } from "jingle-wake-clip";
import { CATALOG_URL, decodeCatalog, type CatalogTrack } from "./catalog";
import { loadCatalog } from "./catalogCache";
import { SOUNDS } from "./sounds";
import type { Alarm, SoundId } from "./types";
import { catalogAudioFilename, librarySoundsUri, renderWakeClip, WAKE_CLIP_SECONDS, wakeClipFilename } from "./wakeClip";

const CACHE_KEY = "jingle.catalog.v1";

export type TrackCacheStatus = {
  audioReady: boolean;
  clipReady: boolean;
};

const inflight = new Map<string, Promise<TrackCacheStatus>>();

function readCached(raw: string | null): CatalogTrack[] {
  if (!raw) return [];
  try {
    return decodeCatalog(JSON.parse(raw) as unknown);
  } catch {
    return [];
  }
}

function seedTracks(): CatalogTrack[] {
  return decodeCatalog(seedCatalog);
}

export async function loadDeviceCatalog(onTracks: (tracks: CatalogTrack[]) => void): Promise<{ offline: boolean }> {
  const cachedRaw = await AsyncStorage.getItem(CACHE_KEY).catch(() => null);
  const cached = readCached(cachedRaw);
  if (cached.length > 0) onTracks(cached);
  else onTracks(seedTracks());
  try {
    const fresh = await loadCatalog({
      read: async () => cachedRaw,
      write: async (value) => {
        await AsyncStorage.setItem(CACHE_KEY, value);
      },
      fetchText: async (url = CATALOG_URL) => {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`catalog ${response.status}`);
        return response.text();
      },
    });
    onTracks(fresh.tracks);
    return { offline: fresh.fromCache };
  } catch {
    return { offline: true };
  }
}

function documentDirectory(): Directory | null {
  // expo-file-system has no web document directory. Skip it instead of probing and warning.
  if (Platform.OS === "web") return null;
  try {
    const directory = Paths.document;
    if (!directory?.uri) return null;
    return directory;
  } catch {
    return null;
  }
}

function audioDirectory(): Directory | null {
  const root = documentDirectory();
  if (!root) return null;
  const directory = new Directory(root, "catalog", "audio");
  try {
    if (!directory.exists) directory.create({ intermediates: true, idempotent: true });
    return directory;
  } catch {
    return null;
  }
}

function soundsDirectory(): Directory | null {
  const root = documentDirectory();
  if (!root) return null;
  const uri = librarySoundsUri(root.uri);
  if (!uri) return null;
  const directory = new Directory(uri.endsWith("/") ? uri : `${uri}/`);
  try {
    if (!directory.exists) directory.create({ intermediates: true, idempotent: true });
    return directory;
  } catch {
    return null;
  }
}

function audioFile(trackId: string): File | null {
  const name = catalogAudioFilename(trackId);
  const directory = audioDirectory();
  if (!name || !directory) return null;
  return new File(directory, name);
}

function clipFile(trackId: string): File | null {
  const name = wakeClipFilename(trackId);
  const directory = soundsDirectory();
  if (!name || !directory) return null;
  return new File(directory, name);
}

export async function clipFileExists(filename: string): Promise<boolean> {
  if (!/^catalog-[a-z0-9][a-z0-9-]{0,79}\.caf$/.test(filename)) return false;
  const directory = soundsDirectory();
  if (!directory) return false;
  try {
    return new File(directory, filename).exists;
  } catch {
    return false;
  }
}

export async function trackCacheStatus(trackId: string): Promise<TrackCacheStatus> {
  try {
    return {
      audioReady: Boolean(audioFile(trackId)?.exists),
      clipReady: Boolean(clipFile(trackId)?.exists),
    };
  } catch {
    return { audioReady: false, clipReady: false };
  }
}

export async function localAudioUri(trackId: string): Promise<string | null> {
  try {
    const file = audioFile(trackId);
    if (!file?.exists) return null;
    return file.uri;
  } catch {
    return null;
  }
}

export async function previewSourceFor(track: CatalogTrack): Promise<string> {
  const local = await localAudioUri(track.id);
  return local ?? track.audioUrl;
}

export async function playbackForAlarm(alarm: Pick<Alarm, "sound" | "catalogTone">): Promise<{ source: number | string; fadeInMs: number }> {
  const bundled = SOUNDS[alarm.sound] ?? SOUNDS.dawn;
  const trackId = alarm.catalogTone?.trackId;
  if (!trackId) return { source: bundled.source, fadeInMs: 0 };
  const uri = await localAudioUri(trackId);
  if (uri) return { source: uri, fadeInMs: 2800 };
  return { source: bundled.source, fadeInMs: 0 };
}

export function bundledPreviewSource(id: SoundId): number {
  return (SOUNDS[id] ?? SOUNDS.dawn).source;
}

type AudioContextLike = {
  decodeAudioData: (buffer: ArrayBuffer) => Promise<AudioBuffer>;
  close: () => Promise<void> | void;
};

function audioContext(): AudioContextLike | null {
  const scope = globalThis as { AudioContext?: new () => AudioContextLike; webkitAudioContext?: new () => AudioContextLike };
  const Factory = scope.AudioContext ?? scope.webkitAudioContext;
  if (!Factory) return null;
  try {
    return new Factory();
  } catch {
    return null;
  }
}

async function clipFromPreviewRange(url: string): Promise<Uint8Array | null> {
  const context = audioContext();
  if (!context) return null;
  try {
    const response = await fetch(url, { headers: { Range: "bytes=0-786431" } });
    if (!response.ok) return null;
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.byteLength < 64 || bytes.byteLength > 1_500_000) return null;
    const audio = await context.decodeAudioData(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
    const rate = audio.sampleRate;
    const channels = audio.numberOfChannels;
    const frames = Math.min(audio.length, Math.floor(WAKE_CLIP_SECONDS * rate));
    if (frames <= 0) return null;
    const mono = new Float32Array(frames);
    for (let frame = 0; frame < frames; frame += 1) {
      let sum = 0;
      for (let channel = 0; channel < channels; channel += 1) sum += audio.getChannelData(channel)[frame] ?? 0;
      mono[frame] = sum / channels;
    }
    return renderWakeClip(mono, rate, 1);
  } catch {
    return null;
  } finally {
    try {
      await context.close();
    } catch {
      // The context was already closed.
    }
  }
}

async function writeWakeClip(track: CatalogTrack, audio: File): Promise<boolean> {
  const clip = clipFile(track.id);
  if (clip) {
    try {
      await exportWakeClip(audio.uri, clip.uri);
      if (clip.exists) return true;
    } catch {
      // Expo Go has no wake-clip native module. A browser can still build the file below.
    }
  }
  const caf = await clipFromPreviewRange(track.audioUrl);
  if (!caf || !clip) return false;
  try {
    const folder = clip.parentDirectory;
    if (!folder.exists) folder.create({ intermediates: true, idempotent: true });
    await clip.write(caf);
    return clip.exists;
  } catch {
    return false;
  }
}

async function saveTrack(track: CatalogTrack, onProgress?: (ratio: number) => void): Promise<TrackCacheStatus> {
  const existing = await trackCacheStatus(track.id);
  if (existing.audioReady && existing.clipReady) {
    onProgress?.(1);
    return existing;
  }
  const file = audioFile(track.id);
  if (!file) return { audioReady: false, clipReady: false };
  if (!existing.audioReady) {
    try {
      await File.downloadFileAsync(track.audioUrl, file, {
        idempotent: true,
        onProgress: ({ bytesWritten, totalBytes }) => {
          if (totalBytes > 0) onProgress?.(Math.max(0, Math.min(0.98, bytesWritten / totalBytes)));
        },
      });
    } catch {
      return { audioReady: Boolean(file.exists), clipReady: false };
    }
  }
  if (!file.exists) return { audioReady: false, clipReady: false };
  const clipReady = await writeWakeClip(track, file);
  onProgress?.(1);
  return { audioReady: true, clipReady };
}

export function ensureCatalogTrack(track: CatalogTrack, onProgress?: (ratio: number) => void): Promise<TrackCacheStatus> {
  const current = inflight.get(track.id);
  if (current) return current;
  const job = saveTrack(track, onProgress).finally(() => {
    inflight.delete(track.id);
  });
  inflight.set(track.id, job);
  return job;
}
