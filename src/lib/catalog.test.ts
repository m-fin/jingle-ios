import assert from "node:assert/strict";
import { test } from "node:test";

import seedCatalog from "../../assets/catalog.seed.json";

import { loadCatalog, prepareCatalogAudio } from "./catalogCache";
import {
  absoluteMediaUrl,
  bpmBadge,
  creditedArtist,
  decodeCatalog,
  filterCatalog,
  formatBytes,
  formatDuration,
  listCollections,
  sanitizeCatalogTone,
  type CatalogTrack,
} from "./catalog";
import { planNotifications } from "./schedule";
import { sanitizeStore } from "./storage";
import type { Alarm } from "./types";
import { readCafPcm16, renderWakeClip, resolveNotificationSound, wakeClipFilename, librarySoundsUri, WAKE_CLIP_SECONDS } from "./wakeClip";

const liveTrack = {
  id: "pale-page",
  title: "Pale Page",
  lane: "Focus",
  journey: "Focus",
  description: "Soft piano.",
  collectionId: "deep-focus",
  collection: "Deep Focus",
  number: 27,
  links: { Audiomack: "https://audiomack.com/sonicrift/song/pale-page-full" },
  bpm: null,
  duration: 1320,
  audio: "/assets/music-library/audio/pale-page.mp3",
  bytes: 21121218,
  cover: "/assets/music-library/art/pale-page-1200.jpg",
  thumb: "/assets/music-library/art/pale-page-400.jpg",
  engine: "Original code-synthesized music",
};

function track(overrides: Partial<CatalogTrack> = {}): CatalogTrack {
  return {
    id: "pale-page",
    title: "Pale Page",
    collection: "Deep Focus",
    collectionId: "deep-focus",
    lane: "Focus",
    bpm: 64,
    bpmLabel: null,
    duration: 1320,
    bytes: 1000,
    audioUrl: "https://matthewfinley.org/assets/music-library/audio/pale-page.mp3",
    thumbUrl: null,
    artUrl: null,
    ...overrides,
  };
}

function alarm(overrides: Partial<Alarm> = {}): Alarm {
  return {
    id: "morning",
    label: "Morning",
    hour: 6,
    minute: 0,
    repeat: [1, 2, 3, 4, 5],
    onceDate: null,
    sound: "dawn",
    snoozeMinutes: 9,
    machineLeadMinutes: 0,
    enabled: true,
    createdAt: 0,
    ...overrides,
  };
}

test("decodes the live catalog shape and ignores other artist names", () => {
  assert.equal(creditedArtist("sonicrift"), "Matthew Finley");
  const tracks = decodeCatalog({
    version: 2,
    artist: "sonicrift",
    tracks: [
      liveTrack,
      {
        id: "warm-box",
        title: "Warm Box",
        collection: "Lamp Hours",
        lane: "Sleep",
        bpm: "86",
        duration: "199.5",
        mp3: "https://matthewfinley.org/assets/music-library/audio/warm-box.mp3",
        art: "/assets/music-library/art/warm-box.jpg",
      },
      {
        id: "free-room",
        title: "Free Room",
        collection: "Rain",
        lane: "Rain",
        bpm: "unmetered / free time",
        duration: 90,
        audio: "/assets/music-library/audio/free-room.mp3",
      },
      { id: "../secret", title: "Nope", audio: "/assets/music-library/audio/nope.mp3" },
      { id: "offsite", title: "Offsite", audio: "https://example.com/track.mp3" },
      { title: "Missing id", audio: "/assets/music-library/audio/missing.mp3" },
    ],
  });
  assert.equal(tracks.length, 3);
  assert.equal(tracks[0]?.id, "pale-page");
  assert.equal(tracks[0]?.title, "Pale Page");
  assert.equal(tracks[0]?.collection, "Deep Focus");
  assert.equal(tracks[0]?.lane, "Focus");
  assert.equal(tracks[0]?.bpm, null);
  assert.equal(tracks[0]?.duration, 1320);
  assert.equal(tracks[0]?.audioUrl, "https://matthewfinley.org/assets/music-library/audio/pale-page.mp3");
  assert.equal(tracks[0]?.thumbUrl, "https://matthewfinley.org/assets/music-library/art/pale-page-400.jpg");
  assert.equal(tracks[0]?.artUrl, "https://matthewfinley.org/assets/music-library/art/pale-page-1200.jpg");
  assert.equal(tracks[1]?.bpm, 86);
  assert.equal(tracks[1]?.duration, 199.5);
  assert.equal(tracks[1]?.thumbUrl, null);
  assert.equal(tracks[1]?.artUrl, "https://matthewfinley.org/assets/music-library/art/warm-box.jpg");
  assert.equal(bpmBadge(tracks[2]!), "Free");
  assert.equal(JSON.stringify(tracks).toLowerCase().includes("sonicrift"), false);
  assert.equal(absoluteMediaUrl("http://matthewfinley.org/assets/a.mp3"), null);
  assert.equal(formatDuration(1320), "22:00");
  assert.equal(formatDuration(74.4), "1:14");
  assert.equal(formatBytes(21121218), "20 MB");
});

test("reads the bundled catalog seed without another artist name", () => {
  const tracks = decodeCatalog(seedCatalog);
  // The live feed has 729 rows and two entries share the id fire-escape.
  assert.equal(tracks.length, 728);
  assert.equal(tracks.some((item) => item.id === "pale-page" && item.title === "Pale Page"), true);
  assert.equal(JSON.stringify(tracks).toLowerCase().includes("sonicrift"), false);
  assert.equal(creditedArtist(seedCatalog), "Matthew Finley");
});

test("decodes a bare track array and a numeric bpm badge", () => {
  const tracks = decodeCatalog([
    { id: "bell-shade", title: "Bell Shade", audio: "/a.mp3", bpm: 72, duration: 80, collection: "Bells", lane: "Calm" },
  ]);
  assert.equal(tracks.length, 1);
  assert.equal(bpmBadge(tracks[0]!), "72 BPM");
  assert.equal(bpmBadge({ bpm: null, bpmLabel: "gentle 76 BPM pulse" }), "76 BPM");
});

test("searches by title, collection, and lane, and filters by collection", () => {
  const tracks = [
    track({ id: "pale-page", title: "Pale Page", collection: "Deep Focus", collectionId: "deep-focus", lane: "Focus" }),
    track({ id: "rain-glass", title: "Rain Glass", collection: "Rain", collectionId: "rain", lane: "Rain", bpm: null, bpmLabel: "unmetered / free time" }),
    track({ id: "night-drive", title: "Night Drive", collection: "Hotel of Tracks", collectionId: "hotel", lane: "Drive" }),
  ];
  assert.deepEqual(filterCatalog(tracks, "pale", null).map((item) => item.id), ["pale-page"]);
  assert.deepEqual(filterCatalog(tracks, "HOTEL", null).map((item) => item.id), ["night-drive"]);
  assert.deepEqual(filterCatalog(tracks, "rain", null).map((item) => item.id), ["rain-glass"]);
  assert.deepEqual(filterCatalog(tracks, "", "deep-focus").map((item) => item.id), ["pale-page"]);
  assert.deepEqual(filterCatalog(tracks, "drive", "rain").map((item) => item.id), []);
  assert.deepEqual(
    listCollections(tracks).map((item) => item.title),
    ["Deep Focus", "Hotel of Tracks", "Rain"],
  );
});

test("caches the catalog and still browses when the network fails", async () => {
  const disk = new Map<string, string>();
  let fetches = 0;
  const io = {
    read: async () => disk.get("catalog") ?? null,
    write: async (value: string) => {
      disk.set("catalog", value);
    },
    fetchText: async () => {
      fetches += 1;
      if (fetches > 1) throw new Error("offline");
      return JSON.stringify({ artist: "sonicrift", tracks: [liveTrack] });
    },
  };
  const first = await loadCatalog(io);
  assert.equal(first.fromCache, false);
  assert.equal(first.tracks.length, 1);
  assert.equal(disk.get("catalog")?.toLowerCase().includes("sonicrift"), false);
  assert.equal(disk.get("catalog")?.includes("Matthew Finley"), true);
  const cached = await loadCatalog(io, { refresh: false });
  assert.equal(fetches, 1);
  assert.equal(cached.fromCache, true);
  assert.equal(cached.tracks[0]?.title, "Pale Page");
  const offline = await loadCatalog(io);
  assert.equal(offline.fromCache, true);
  assert.equal(offline.tracks[0]?.id, "pale-page");
});

test("keeps audio when the wake clip export fails, and keeps nothing when the download fails", async () => {
  const audio = new Map<string, Uint8Array>();
  const clips = new Map<string, Uint8Array>();
  const saved = await prepareCatalogAudio(track(), {
    fetchBytes: async (_url, onProgress) => {
      onProgress?.(0.4);
      return Uint8Array.from([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]);
    },
    saveAudio: async (filename, bytes) => {
      audio.set(filename, bytes);
    },
    exportClip: async () => null,
    saveClip: async (filename, bytes) => {
      clips.set(filename, bytes);
    },
  });
  assert.equal(saved.audioReady, true);
  assert.equal(saved.clipReady, false);
  assert.equal(audio.has("pale-page.mp3"), true);
  assert.equal(clips.size, 0);

  const downloaded = await prepareCatalogAudio(track({ id: "rain-glass" }), {
    fetchBytes: async () => new Uint8Array(64),
    saveAudio: async (filename, bytes) => {
      audio.set(filename, bytes);
    },
    exportClip: async () => new Uint8Array(80),
    saveClip: async (filename, bytes) => {
      clips.set(filename, bytes);
    },
  });
  assert.deepEqual(downloaded, { audioReady: true, clipReady: true });
  assert.equal(clips.has("catalog-rain-glass.caf"), true);

  const missed = await prepareCatalogAudio(track({ id: "missing-file" }), {
    fetchBytes: async () => {
      throw new Error("network");
    },
    saveAudio: async () => {
      throw new Error("should not save");
    },
    exportClip: async () => null,
    saveClip: async () => undefined,
  });
  assert.deepEqual(missed, { audioReady: false, clipReady: false });
});

test("serializes a catalog tone and still accepts the original bundled alarms", () => {
  const legacy = sanitizeStore({
    version: 1,
    seeded: true,
    alarms: [alarm()],
    snoozes: [],
    settings: { theme: "night", autoBlank: true, bedsideDim: true },
  });
  assert.equal(legacy?.alarms[0]?.sound, "dawn");
  assert.equal(legacy?.alarms[0]?.catalogTone, null);

  const saved = sanitizeStore({
    version: 1,
    seeded: true,
    alarms: [
      alarm({
        sound: "bell",
        catalogTone: { trackId: "pale-page", title: "Pale Page", collection: "Deep Focus" },
      }),
      alarm({
        id: "bad",
        catalogTone: { trackId: "../Library", title: "Nope", collection: "X" },
      }),
      alarm({
        id: "renamed",
        catalogTone: { trackId: "rain-glass", title: "sonicrift session", collection: "Rain" },
      }),
    ],
    snoozes: [],
    settings: {},
  });
  assert.equal(saved?.alarms[0]?.sound, "bell");
  assert.deepEqual(saved?.alarms[0]?.catalogTone, {
    trackId: "pale-page",
    title: "Pale Page",
    collection: "Deep Focus",
  });
  assert.equal(saved?.alarms[1]?.catalogTone, null);
  assert.equal(saved?.alarms[1]?.sound, "dawn");
  assert.equal(saved?.alarms[2]?.catalogTone?.title, "Matthew Finley session");
  assert.equal(JSON.stringify(saved).toLowerCase().includes("sonicrift"), false);
  assert.deepEqual(sanitizeCatalogTone({ trackId: "not valid", title: "X" }), null);
});

test("plans a catalog wake clip and falls back to Dawn when that file is missing", () => {
  const now = new Date(2026, 10, 16, 5, 0, 0);
  const planned = planNotifications(
    [alarm({ catalogTone: { trackId: "pale-page", title: "Pale Page", collection: "Deep Focus" }, machineLeadMinutes: 10, sound: "bell" })],
    [],
    now,
  );
  const ring = planned.find((item) => item.purpose === "alarm");
  const machine = planned.find((item) => item.purpose === "machine");
  assert.equal(ring?.catalogClip, "catalog-pale-page.caf");
  assert.equal(ring?.sound, "bell");
  assert.equal(machine?.catalogClip ?? null, null);
  assert.equal(machine?.sound, "machine");
  assert.equal(wakeClipFilename("pale-page"), "catalog-pale-page.caf");
  assert.equal(wakeClipFilename("../pale-page"), null);
  assert.equal(librarySoundsUri("file:///var/mobile/Containers/Data/Application/abc/Documents"), "file:///var/mobile/Containers/Data/Application/abc/Library/Sounds");
  assert.equal(librarySoundsUri("file:///tmp/elsewhere"), null);
  assert.equal(
    resolveNotificationSound({ sound: "bell", catalogClip: "catalog-pale-page.caf", clipReady: true, platform: "ios" }),
    "catalog-pale-page.caf",
  );
  assert.equal(
    resolveNotificationSound({ sound: "bell", catalogClip: "catalog-pale-page.caf", clipReady: false, platform: "ios" }),
    "bell.wav",
  );
  assert.equal(
    resolveNotificationSound({ sound: "bell", catalogClip: "catalog-pale-page.caf", clipReady: true, platform: "android" }),
    "bell.wav",
  );
  assert.equal(resolveNotificationSound({ sound: "machine", catalogClip: "catalog-pale-page.caf", clipReady: true, platform: "ios" }), "machine.wav");
  assert.equal(resolveNotificationSound({ sound: "chime", catalogClip: null, clipReady: false, platform: "ios" }), "chime.wav");
});

test("exports a 28 second wake clip with a fade in and fade out", () => {
  const sampleRate = 8000;
  const frames = sampleRate * 40;
  const input = new Float32Array(frames);
  input.fill(1);
  const caf = renderWakeClip(input, sampleRate, 1);
  const decoded = readCafPcm16(caf);
  assert.equal(decoded.sampleRate, sampleRate);
  assert.equal(decoded.samples.length, sampleRate * WAKE_CLIP_SECONDS);
  assert.equal(decoded.samples[0], 0);
  const middle = decoded.samples[sampleRate * 10] ?? 0;
  const last = decoded.samples[decoded.samples.length - 1] ?? 0;
  assert.ok(middle > 30000, `middle sample ${middle}`);
  assert.ok(Math.abs(last) < 2000, `last sample ${last}`);
  const early = decoded.samples[Math.floor(sampleRate * 0.2)] ?? 0;
  assert.ok(early > 0 && early < middle);
});
