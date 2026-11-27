import { Directory, File, Paths } from "expo-file-system";

import { catalogAudioPath, catalogWakeFilename, librarySoundsPath, safeTrackId } from "./tone";

function documentUri(): string | null {
  try {
    const uri = Paths.document.uri;
    return typeof uri === "string" && uri.length > 0 ? uri : null;
  } catch {
    return null;
  }
}

export function localCatalogAudioUri(trackId: string): string | null {
  const root = documentUri();
  const path = root ? catalogAudioPath(root, trackId) : null;
  if (!path) return null;
  try {
    const file = new File(path);
    if (!file.exists || file.size < 1024) return null;
    return file.uri;
  } catch {
    return null;
  }
}

export function wakeClipReady(filename: string | null): boolean {
  if (!filename || !filename.startsWith("catalog-") || !filename.endsWith(".caf")) return false;
  const root = documentUri();
  const sounds = root ? librarySoundsPath(root) : null;
  if (!sounds) return false;
  try {
    const file = new File(sounds, filename);
    return file.exists && file.size > 1024;
  } catch {
    return false;
  }
}

export function ensureCatalogAudioFile(trackId: string): File | null {
  const id = safeTrackId(trackId);
  const root = documentUri();
  if (!id || !root) return null;
  try {
    const directory = new Directory(root, "catalog", "audio");
    if (!directory.exists) directory.create({ intermediates: true, idempotent: true });
    return new File(directory, `${id}.mp3`);
  } catch {
    return null;
  }
}

export function ensureWakeClipFile(trackId: string): File | null {
  const filename = catalogWakeFilename(trackId);
  const root = documentUri();
  const sounds = root ? librarySoundsPath(root) : null;
  if (!filename || !sounds) return null;
  try {
    const directory = new Directory(sounds);
    if (!directory.exists) directory.create({ intermediates: true, idempotent: true });
    return new File(directory, filename);
  } catch {
    return null;
  }
}
