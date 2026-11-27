import type { SoundId } from "./types";

/** Artist credit for every catalog wake tone. Never substitute another name. */
export const CATALOG_ARTIST = "Matthew Finley";

export const DEFAULT_WAKE_ID: SoundId = "dawn";
export const DEFAULT_WAKE_FILE = "dawn.wav";
export const MACHINE_WAKE_FILE = "machine.wav";

export const BUNDLED_WAKE_FILES: Record<SoundId, string> = {
  dawn: "dawn.wav",
  bell: "bell.wav",
  pulse: "pulse.wav",
  chime: "chime.wav",
};

export const BUNDLED_WAKE_NAMES: Record<SoundId, string> = {
  dawn: "Dawn",
  bell: "Bell",
  pulse: "Pulse",
  chime: "Chime",
};

export type CatalogTone = {
  trackId: string;
  title: string;
  collection: string;
  lane: string;
};

const TRACK_ID = /^[a-z0-9][a-z0-9-]{0,95}$/;

export function safeTrackId(value: string): string | null {
  const cleaned = value.trim().toLowerCase();
  if (!cleaned || cleaned.includes("sonicrift") || cleaned.includes("..") || /[^a-z0-9-]/.test(cleaned)) return null;
  if (!TRACK_ID.test(cleaned)) return null;
  return cleaned;
}

export function cleanPublicText(value: string, fallback = ""): string {
  const text = value
    .replace(/sonicrift/gi, CATALOG_ARTIST)
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 80);
  return text || fallback;
}

export function catalogWakeFilename(trackId: string): string | null {
  const id = safeTrackId(trackId);
  if (!id) return null;
  return `catalog-${id}.caf`;
}

export function bundledWakeFile(sound: SoundId | "machine" | string): string {
  if (sound === "machine") return MACHINE_WAKE_FILE;
  if (sound in BUNDLED_WAKE_FILES) return BUNDLED_WAKE_FILES[sound as SoundId];
  return DEFAULT_WAKE_FILE;
}

/**
 * Filename passed to the scheduled notification.
 * A catalog clip is used only when that file is already on disk.
 * Anything else falls back to the alarm's bundled tone, or Dawn.
 */
export function resolveNotificationSound(input: {
  sound: SoundId | "machine" | string;
  catalogTrackId?: string | null;
  clipReady: boolean;
}): string {
  if (input.sound === "machine") return MACHINE_WAKE_FILE;
  if (input.clipReady && input.catalogTrackId) {
    const filename = catalogWakeFilename(input.catalogTrackId);
    if (filename) return filename;
  }
  return bundledWakeFile(input.sound);
}

export function sanitizeCatalogTone(value: unknown): CatalogTone | null {
  if (typeof value !== "object" || value === null) return null;
  const record = value as Record<string, unknown>;
  const trackId = typeof record.trackId === "string" ? safeTrackId(record.trackId) : null;
  if (!trackId) return null;
  const title = cleanPublicText(typeof record.title === "string" ? record.title : "", "Track");
  const collection = cleanPublicText(typeof record.collection === "string" ? record.collection : "", CATALOG_ARTIST);
  const lane = cleanPublicText(typeof record.lane === "string" ? record.lane : "");
  return { trackId, title, collection, lane };
}

export function alarmToneName(alarm: { sound: SoundId; catalog?: CatalogTone | null }): string {
  if (alarm.catalog?.title) return alarm.catalog.title;
  return BUNDLED_WAKE_NAMES[alarm.sound] ?? BUNDLED_WAKE_NAMES[DEFAULT_WAKE_ID];
}

export function librarySoundsPath(documentDirectory: string): string | null {
  const trimmed = documentDirectory.replace(/\/+$/, "");
  const marker = "/Documents";
  if (!trimmed.endsWith(marker)) return null;
  return `${trimmed.slice(0, -marker.length)}/Library/Sounds`;
}

export function catalogJsonPath(root: string): string {
  return `${root.replace(/\/+$/, "")}/catalog/catalog.json`;
}

export function catalogAudioPath(root: string, trackId: string): string | null {
  const id = safeTrackId(trackId);
  if (!id) return null;
  return `${root.replace(/\/+$/, "")}/catalog/audio/${id}.mp3`;
}

export function wakeClipPath(documentDirectory: string, trackId: string): string | null {
  const sounds = librarySoundsPath(documentDirectory);
  const filename = catalogWakeFilename(trackId);
  if (!sounds || !filename) return null;
  return `${sounds}/${filename}`;
}
