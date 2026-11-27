import AsyncStorage from "@react-native-async-storage/async-storage";
import { File, Paths } from "expo-file-system";

import { CATALOG_URL, mediaUrl, resolveCatalog, type CatalogLoad, type CatalogTrack } from "./catalog";
import { emitCatalogReady } from "./catalogReady";
import { ensureCatalogAudioFile, ensureWakeClipFile, localCatalogAudioUri } from "./catalogPlayback";
import { decodeMp3Clip } from "./mp3Decode";
import { catalogJsonPath } from "./tone";
import { clipByteLength, renderWakeClip } from "./wakeClip";

const CACHE_KEY = "jingle.catalog.v1";

async function readCatalogCacheText(): Promise<string | null> {
  try {
    const root = Paths.document.uri;
    const file = new File(catalogJsonPath(root));
    if (file.exists && file.size > 2) return await file.text();
  } catch {
    // The document directory is not available in every preview. Storage is the other copy.
  }
  try {
    return await AsyncStorage.getItem(CACHE_KEY);
  } catch {
    return null;
  }
}

async function writeCatalogCacheText(text: string): Promise<void> {
  try {
    await AsyncStorage.setItem(CACHE_KEY, text);
  } catch {
    // A file copy below can still serve the next launch.
  }
  try {
    const root = Paths.document.uri;
    const file = new File(catalogJsonPath(root));
    const parent = file.parentDirectory;
    if (!parent.exists) parent.create({ intermediates: true, idempotent: true });
    await file.write(text);
  } catch {
    // AsyncStorage already holds the catalog when the file system cannot.
  }
}

async function fetchLiveCatalog(): Promise<unknown> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15_000);
  try {
    const response = await fetch(CATALOG_URL, {
      signal: controller.signal,
      headers: { Accept: "application/json" },
    });
    if (!response.ok) throw new Error(`catalog ${response.status}`);
    return (await response.json()) as unknown;
  } finally {
    clearTimeout(timer);
  }
}

export function loadMatthewFinleyCatalog(): Promise<CatalogLoad> {
  return resolveCatalog({
    fetchCatalog: fetchLiveCatalog,
    readCache: readCatalogCacheText,
    writeCache: writeCatalogCacheText,
  });
}

export type DownloadPhase = "downloading" | "preparing" | "ready" | "error";

export async function prepareCatalogWake(
  track: CatalogTrack,
  onProgress: (phase: DownloadPhase, progress: number) => void,
): Promise<"ready" | "audio" | "failed"> {
  const remote = mediaUrl(track.audioPath);
  const destination = ensureCatalogAudioFile(track.id);
  if (!remote || !destination) return "failed";
  try {
    if (!localCatalogAudioUri(track.id)) {
      onProgress("downloading", 0);
      await File.downloadFileAsync(remote, destination, {
        idempotent: true,
        onProgress: ({ bytesWritten, totalBytes }) => {
          if (totalBytes > 0) onProgress("downloading", Math.max(0, Math.min(1, bytesWritten / totalBytes)));
        },
      });
    }
    if (!localCatalogAudioUri(track.id)) return "failed";
    onProgress("preparing", 1);
    await new Promise((resolve) => setTimeout(resolve, 32));
    const length = clipByteLength(destination.size, track.duration);
    const handle = destination.open();
    let prefix: Uint8Array;
    try {
      prefix = await handle.readBytes(Math.max(length, 1));
    } finally {
      handle.close();
    }
    const pcm = await decodeMp3Clip(prefix);
    if (!pcm && destination.size < 64 * 1024) {
      try {
        destination.delete();
      } catch {
        // A partial file can be removed on the next attempt.
      }
      return "failed";
    }
    const clip = pcm ? renderWakeClip(pcm) : null;
    const wake = clip ? ensureWakeClipFile(track.id) : null;
    if (!clip || !wake) return "audio";
    await wake.write(clip);
    onProgress("ready", 1);
    emitCatalogReady();
    return "ready";
  } catch {
    return localCatalogAudioUri(track.id) ? "audio" : "failed";
  }
}
