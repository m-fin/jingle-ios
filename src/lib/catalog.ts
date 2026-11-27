import { CATALOG_ARTIST, cleanPublicText, safeTrackId, type CatalogTone } from "./tone";

export const CATALOG_URL = "https://matthewfinley.org/music/catalog.json";
export const CATALOG_ORIGIN = "https://matthewfinley.org";

export type CatalogTrack = {
  id: string;
  title: string;
  collection: string;
  lane: string;
  bpm: number | null;
  duration: number;
  audioPath: string;
  thumbPath: string;
  artPath: string;
};

export type CatalogCacheFile = {
  version: 1;
  artist: typeof CATALOG_ARTIST;
  fetchedAt: string;
  tracks: CatalogTrack[];
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function parseBpm(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value > 0 && value < 400) return value;
  if (typeof value !== "string") return null;
  const match = /^(\d+(?:\.\d+)?)/.exec(value.trim());
  if (!match) return null;
  const parsed = Number(match[1]);
  if (!Number.isFinite(parsed) || parsed <= 0 || parsed >= 400) return null;
  return parsed;
}

function parseDuration(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : typeof value === "string" ? Number(value) : NaN;
  if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 60 * 60 * 6) return null;
  return parsed;
}

function firstString(record: Record<string, unknown>, keys: string[]): string {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return "";
}

function mediaPath(value: string): string | null {
  const path = value.trim();
  if (!path || path.toLowerCase().includes("sonicrift") || path.includes("..")) return null;
  if (path.startsWith("/") && !path.startsWith("//")) return path;
  if (path.startsWith("https://matthewfinley.org/")) return path;
  return null;
}

export function mediaUrl(pathOrUrl: string): string | null {
  const path = mediaPath(pathOrUrl);
  if (!path) return null;
  if (path.startsWith("https://")) {
    try {
      const url = new URL(path);
      if (url.protocol !== "https:" || url.hostname !== "matthewfinley.org") return null;
      return url.toString();
    } catch {
      return null;
    }
  }
  return `${CATALOG_ORIGIN}${path}`;
}

function decodeTrack(record: Record<string, unknown>): CatalogTrack | null {
  const id = safeTrackId(firstString(record, ["id", "trackId"]));
  const title = cleanPublicText(firstString(record, ["title", "name"]), "");
  const audioPath = mediaPath(firstString(record, ["audioPath", "audio", "src", "file"]));
  const duration = parseDuration(record.duration ?? record.length);
  if (!id || !title || !audioPath || duration === null) return null;
  const thumbPath = mediaPath(firstString(record, ["thumbPath", "thumb", "art", "cover", "artwork"])) ?? "";
  const artPath = mediaPath(firstString(record, ["artPath", "art", "cover", "thumb", "artwork"])) ?? thumbPath;
  return {
    id,
    title,
    collection: cleanPublicText(firstString(record, ["collection", "album", "collectionId"]), CATALOG_ARTIST),
    lane: cleanPublicText(firstString(record, ["lane", "journey", "mood"])),
    bpm: parseBpm(record.bpm),
    duration,
    audioPath,
    thumbPath,
    artPath,
  };
}

function trackRecords(value: unknown): Record<string, unknown>[] {
  if (Array.isArray(value)) return value.filter(isRecord);
  if (!isRecord(value) || !Array.isArray(value.tracks)) return [];
  return value.tracks.filter(isRecord);
}

/** Accepts the live catalog document or the normalized cache written by Jingle. */
export function decodeCatalog(value: unknown): CatalogTrack[] {
  const tracks: CatalogTrack[] = [];
  const seen = new Set<string>();
  for (const record of trackRecords(value)) {
    const track = decodeTrack(record);
    if (!track || seen.has(track.id)) continue;
    seen.add(track.id);
    tracks.push(track);
  }
  return tracks;
}

export function catalogCacheDocument(tracks: CatalogTrack[], fetchedAt: string): CatalogCacheFile {
  return {
    version: 1,
    artist: CATALOG_ARTIST,
    fetchedAt,
    tracks,
  };
}

export function filterCatalogTracks(tracks: CatalogTrack[], query: string, collection: string | null): CatalogTrack[] {
  const needle = query.trim().toLowerCase();
  return tracks.filter((track) => {
    if (collection && track.collection !== collection) return false;
    if (!needle) return true;
    return (
      track.title.toLowerCase().includes(needle) ||
      track.collection.toLowerCase().includes(needle) ||
      track.lane.toLowerCase().includes(needle)
    );
  });
}

export function catalogCollections(tracks: CatalogTrack[]): string[] {
  return [...new Set(tracks.map((track) => track.collection).filter(Boolean))].sort((a, b) => a.localeCompare(b));
}

export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds < 0) return "";
  const total = Math.round(seconds);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const remain = total % 60;
  if (hours > 0) return `${hours}:${String(minutes).padStart(2, "0")}:${String(remain).padStart(2, "0")}`;
  return `${minutes}:${String(remain).padStart(2, "0")}`;
}

export function formatBpm(bpm: number | null): string | null {
  if (bpm === null || !Number.isFinite(bpm) || bpm <= 0) return null;
  return `${Math.round(bpm)} BPM`;
}

export function trackBadge(track: Pick<CatalogTrack, "duration" | "bpm">): string {
  const duration = formatDuration(track.duration);
  const bpm = formatBpm(track.bpm);
  return bpm ? `${duration} · ${bpm}` : duration;
}

export function toCatalogTone(track: CatalogTrack): CatalogTone {
  return {
    trackId: track.id,
    title: track.title,
    collection: track.collection,
    lane: track.lane,
  };
}

export type CatalogLoad = {
  tracks: CatalogTrack[];
  source: "network" | "cache" | "empty";
};

export async function resolveCatalog(options: {
  fetchCatalog: () => Promise<unknown>;
  readCache: () => Promise<string | null>;
  writeCache: (text: string) => Promise<void>;
  now?: Date;
}): Promise<CatalogLoad> {
  try {
    const raw = await options.fetchCatalog();
    const tracks = decodeCatalog(raw);
    if (tracks.length === 0) throw new Error("empty catalog");
    const document = catalogCacheDocument(tracks, (options.now ?? new Date()).toISOString());
    await options.writeCache(JSON.stringify(document));
    return { tracks, source: "network" };
  } catch {
    const text = await options.readCache().catch(() => null);
    if (!text) return { tracks: [], source: "empty" };
    try {
      const tracks = decodeCatalog(JSON.parse(text) as unknown);
      if (tracks.length === 0) return { tracks: [], source: "empty" };
      return { tracks, source: "cache" };
    } catch {
      return { tracks: [], source: "empty" };
    }
  }
}
