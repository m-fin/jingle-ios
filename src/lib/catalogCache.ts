import { CATALOG_ARTIST, CATALOG_URL, decodeCatalog, type CatalogTrack } from "./catalog";
import { catalogAudioFilename, wakeClipFilename } from "./wakeClip";

export type CatalogLoad = {
  tracks: CatalogTrack[];
  fromCache: boolean;
};

function parseJson(raw: string): unknown {
  return JSON.parse(raw) as unknown;
}

export function catalogCachePayload(tracks: CatalogTrack[]): string {
  return JSON.stringify({ artist: CATALOG_ARTIST, tracks });
}

export async function loadCatalog(
  io: {
    read: () => Promise<string | null>;
    write: (value: string) => Promise<void>;
    fetchText: (url: string) => Promise<string>;
  },
  options?: { refresh?: boolean },
): Promise<CatalogLoad> {
  const cachedRaw = await io.read().catch(() => null);
  const cached = cachedRaw ? decodeCatalog(parseJsonSafe(cachedRaw)) : [];
  if (cached.length > 0 && options?.refresh === false) return { tracks: cached, fromCache: true };
  try {
    const text = await io.fetchText(CATALOG_URL);
    const tracks = decodeCatalog(parseJson(text));
    if (tracks.length === 0) throw new Error("empty catalog");
    const payload = catalogCachePayload(tracks);
    if (payload.toLowerCase().includes("sonicrift")) throw new Error("catalog attribution");
    await io.write(payload);
    return { tracks, fromCache: false };
  } catch (error) {
    if (cached.length > 0) return { tracks: cached, fromCache: true };
    if (error instanceof Error && error.message === "catalog attribution") throw error;
    throw new Error("catalog-unavailable");
  }
}

function parseJsonSafe(raw: string): unknown {
  try {
    return parseJson(raw);
  } catch {
    return null;
  }
}

export type PrepareResult = {
  audioReady: boolean;
  clipReady: boolean;
};

/**
 * Saves a track's audio, then a notification clip.
 * A failed clip still keeps the audio. A failed download keeps neither, and the alarm uses Dawn.
 */
export async function prepareCatalogAudio(
  track: CatalogTrack,
  io: {
    fetchBytes: (url: string, onProgress?: (ratio: number) => void) => Promise<Uint8Array>;
    saveAudio: (filename: string, bytes: Uint8Array) => Promise<void>;
    exportClip: (audioFilename: string, bytes: Uint8Array) => Promise<Uint8Array | null>;
    saveClip: (filename: string, bytes: Uint8Array) => Promise<void>;
  },
  onProgress?: (ratio: number) => void,
): Promise<PrepareResult> {
  const audioName = catalogAudioFilename(track.id);
  const clipName = wakeClipFilename(track.id);
  if (!audioName || !clipName) return { audioReady: false, clipReady: false };
  let bytes: Uint8Array;
  try {
    bytes = await io.fetchBytes(track.audioUrl, onProgress);
  } catch {
    return { audioReady: false, clipReady: false };
  }
  if (bytes.byteLength < 32) return { audioReady: false, clipReady: false };
  try {
    await io.saveAudio(audioName, bytes);
  } catch {
    return { audioReady: false, clipReady: false };
  }
  onProgress?.(1);
  try {
    const clip = await io.exportClip(audioName, bytes);
    if (!clip || clip.byteLength < 64) return { audioReady: true, clipReady: false };
    await io.saveClip(clipName, clip);
    return { audioReady: true, clipReady: true };
  } catch {
    return { audioReady: true, clipReady: false };
  }
}
