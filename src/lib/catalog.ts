import type { CatalogTone } from "./types";

export const CATALOG_ORIGIN = "https://matthewfinley.org";
export const CATALOG_URL = `${CATALOG_ORIGIN}/music/catalog.json`;

/** Shown everywhere a catalog tone is credited. The feed's other names are ignored. */
export const CATALOG_ARTIST = "Matthew Finley";

export type CatalogTrack = {
  id: string;
  title: string;
  collection: string;
  collectionId: string;
  lane: string;
  bpm: number | null;
  bpmLabel: string | null;
  duration: number;
  bytes: number | null;
  audioUrl: string;
  thumbUrl: string | null;
  artUrl: string | null;
};

export type CatalogCollection = {
  id: string;
  title: string;
  count: number;
};

const TRACK_ID = /^[a-z0-9][a-z0-9-]{0,79}$/;

export function creditedArtist(fromCatalog?: unknown): string {
  void fromCatalog;
  return CATALOG_ARTIST;
}

export function publicText(value: string): string {
  return value.replace(/sonicrift/gi, CATALOG_ARTIST).replace(/\s{2,}/g, " ").trim();
}

export function safeTrackId(value: string): string | null {
  const id = value.trim();
  if (!TRACK_ID.test(id)) return null;
  if (id.includes("sonicrift")) return null;
  return id;
}

export function absoluteMediaUrl(value: string): string | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  try {
    const url = trimmed.startsWith("/") ? new URL(trimmed, CATALOG_ORIGIN) : new URL(trimmed);
    if (url.protocol !== "https:") return null;
    if (url.username || url.password) return null;
    if (url.hostname !== "matthewfinley.org") return null;
    return url.toString();
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringField(record: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function finiteNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && /^-?\d+(\.\d+)?$/.test(value.trim())) {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

export function parseBpm(value: unknown): { bpm: number | null; bpmLabel: string | null } {
  const direct = finiteNumber(value);
  if (direct != null && direct > 0 && direct < 400) return { bpm: direct, bpmLabel: null };
  if (typeof value !== "string") return { bpm: null, bpmLabel: null };
  const text = publicText(value);
  if (!text) return { bpm: null, bpmLabel: null };
  const simple = text.match(/^(\d+(?:\.\d+)?)(?:\s*bpm)?$/i);
  if (simple) {
    const bpm = Number(simple[1]);
    if (bpm > 0 && bpm < 400) return { bpm, bpmLabel: null };
  }
  if (/unmetered|free time|no conventional|pulse-free/i.test(text)) return { bpm: null, bpmLabel: text };
  const mentioned = [...text.matchAll(/(\d+(?:\.\d+)?)\s*bpm/gi)];
  if (mentioned.length === 1) {
    const bpm = Number(mentioned[0][1]);
    if (bpm > 0 && bpm < 400) return { bpm, bpmLabel: null };
  }
  return { bpm: null, bpmLabel: text };
}

export function bpmBadge(track: Pick<CatalogTrack, "bpm" | "bpmLabel">): string | null {
  if (track.bpm != null && track.bpm > 0 && track.bpm < 400) return `${Math.round(track.bpm)} BPM`;
  if (!track.bpmLabel) return null;
  const parsed = parseBpm(track.bpmLabel);
  if (parsed.bpm != null) return `${Math.round(parsed.bpm)} BPM`;
  if (/unmetered|free time|no conventional|pulse-free/i.test(track.bpmLabel)) return "Free";
  return null;
}

export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return "0:00";
  const total = Math.round(seconds);
  const minutes = Math.floor(total / 60);
  const remain = total % 60;
  return `${minutes}:${String(remain).padStart(2, "0")}`;
}

export function formatBytes(bytes: number | null): string | null {
  if (bytes == null || !Number.isFinite(bytes) || bytes <= 0) return null;
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  const mb = bytes / (1024 * 1024);
  return `${mb >= 10 ? Math.round(mb) : mb.toFixed(1)} MB`;
}

function decodeTrack(value: unknown): CatalogTrack | null {
  if (!isRecord(value)) return null;
  const id = typeof value.id === "string" ? safeTrackId(value.id) : null;
  const title = typeof value.title === "string" ? publicText(value.title).slice(0, 160) : "";
  const audioRaw = stringField(value, ["audioUrl", "audio", "mp3", "file"]);
  const audioUrl = audioRaw ? absoluteMediaUrl(audioRaw) : null;
  if (!id || !title || !audioUrl) return null;
  const collection = publicText(stringField(value, ["collection", "album"]) ?? "").slice(0, 160);
  const collectionIdRaw = stringField(value, ["collectionId", "collection_id"]) ?? "";
  const collectionId = safeTrackId(collectionIdRaw) ?? (collection ? collection.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 80) : "");
  const lane = publicText(stringField(value, ["lane", "mood", "journey"]) ?? "").slice(0, 80);
  const duration = finiteNumber(value.duration);
  const bytes = finiteNumber(value.bytes);
  const tempo = value.bpm == null ? parseBpm(value.bpmLabel ?? value.bpm) : parseBpm(value.bpm);
  const thumbRaw = stringField(value, ["thumbUrl", "thumb", "thumbnail"]);
  const artRaw = stringField(value, ["artUrl", "art", "cover", "image"]) ?? thumbRaw;
  return {
    id,
    title,
    collection,
    collectionId,
    lane,
    bpm: tempo.bpm,
    bpmLabel: tempo.bpmLabel,
    duration: duration != null && duration > 0 ? duration : 0,
    bytes: bytes != null && bytes > 0 ? Math.round(bytes) : null,
    audioUrl,
    thumbUrl: thumbRaw ? absoluteMediaUrl(thumbRaw) : null,
    artUrl: artRaw ? absoluteMediaUrl(artRaw) : null,
  };
}

function trackList(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  if (!isRecord(value)) return [];
  if (Array.isArray(value.tracks)) return value.tracks;
  if (Array.isArray(value.items)) return value.items;
  return [];
}

export function decodeCatalog(value: unknown): CatalogTrack[] {
  const seen = new Set<string>();
  const tracks: CatalogTrack[] = [];
  for (const item of trackList(value)) {
    const track = decodeTrack(item);
    if (!track || seen.has(track.id)) continue;
    seen.add(track.id);
    tracks.push(track);
  }
  return tracks;
}

export function filterCatalog(tracks: CatalogTrack[], query: string, collection: string | null): CatalogTrack[] {
  const needle = query.trim().toLowerCase();
  const collectionKey = collection?.trim().toLowerCase() ?? "";
  return tracks.filter((track) => {
    if (collectionKey) {
      const id = track.collectionId.toLowerCase();
      const name = track.collection.toLowerCase();
      if (id !== collectionKey && name !== collectionKey) return false;
    }
    if (!needle) return true;
    return (
      track.title.toLowerCase().includes(needle) ||
      track.collection.toLowerCase().includes(needle) ||
      track.lane.toLowerCase().includes(needle)
    );
  });
}

export function listCollections(tracks: CatalogTrack[]): CatalogCollection[] {
  const map = new Map<string, CatalogCollection>();
  for (const track of tracks) {
    const id = track.collectionId || track.collection;
    if (!id) continue;
    const existing = map.get(id);
    if (existing) existing.count += 1;
    else map.set(id, { id, title: track.collection || id, count: 1 });
  }
  return [...map.values()].sort((a, b) => a.title.localeCompare(b.title) || a.id.localeCompare(b.id));
}

export function sanitizeCatalogTone(value: unknown): CatalogTone | null {
  if (!isRecord(value)) return null;
  const trackId = typeof value.trackId === "string" ? safeTrackId(value.trackId) : null;
  const title = typeof value.title === "string" ? publicText(value.title).slice(0, 160) : "";
  if (!trackId || !title) return null;
  const collection = typeof value.collection === "string" ? publicText(value.collection).slice(0, 160) : "";
  return { trackId, title, collection };
}
