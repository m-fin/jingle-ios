import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import {
  catalogCollections,
  decodeCatalog,
  filterCatalogTracks,
  formatBpm,
  mediaUrl,
  resolveCatalog,
  trackBadge,
} from "./catalog";
import { decodeMp3Clip } from "./mp3Decode";
import { planNotifications } from "./schedule";
import { sanitizeStore } from "./storage";
import {
  alarmToneName,
  catalogAudioPath,
  catalogJsonPath,
  catalogWakeFilename,
  CATALOG_ARTIST,
  librarySoundsPath,
  resolveNotificationSound,
  safeTrackId,
  wakeClipPath,
} from "./tone";
import { clipByteLength, frameGain, renderWakeClip, WAKE_CLIP_SECONDS } from "./wakeClip";

const liveCatalog = {
  version: 2,
  built: "2026-11-25T00:57:59-0500",
  artist: "sonicrift",
  project: "Matthew Finley",
  tracks: [
    {
      id: "pale-page",
      title: "Pale Page",
      lane: "Focus",
      journey: "Focus",
      description: "Soft piano. Not stored.",
      collectionId: "deep-focus",
      collection: "Deep Focus",
      links: { Audiomack: "https://audiomack.com/sonicrift/song/pale-page-full" },
      bpm: null,
      duration: 1320,
      audio: "/assets/music-library/audio/pale-page.mp3",
      cover: "/assets/music-library/art/pale-page-1200.jpg",
      thumb: "/assets/music-library/art/pale-page-400.jpg",
      bytes: 21121218,
    },
    {
      id: "fire-escape",
      title: "Fire Escape",
      lane: "City",
      collection: "Lamp Hours & early works",
      bpm: 78.2,
      duration: "107.416",
      audio: "/assets/music-library/audio/fire-escape.mp3",
      thumb: "/assets/music-library/art/fire-escape-400.jpg",
    },
    {
      id: "clock-shop",
      title: "Clock Shop",
      mood: "Library",
      collection: "Lamp Hours & early works",
      bpm: "86",
      duration: 180,
      src: "https://matthewfinley.org/assets/music-library/audio/clock-shop.mp3",
      artwork: "/assets/music-library/art/clock-shop-400.jpg",
    },
    {
      id: "open-air",
      title: "Open Air",
      lane: "Coastal",
      collection: "Hotel of Tracks",
      bpm: "unmetered / free time",
      duration: 240,
      audio: "/assets/music-library/audio/open-air.mp3",
      cover: "/assets/music-library/art/open-air-1200.jpg",
    },
    {
      id: "../secret",
      title: "Should drop",
      lane: "Focus",
      collection: "Deep Focus",
      bpm: 90,
      duration: 100,
      audio: "/assets/music-library/audio/nope.mp3",
    },
    {
      id: "sonicrift-demo",
      title: "Hidden",
      lane: "Focus",
      collection: "Deep Focus",
      duration: 100,
      audio: "https://example.com/sonicrift/track.mp3",
    },
  ],
};

test("decodes the live catalog shape and drops private or off-site fields", () => {
  const tracks = decodeCatalog(liveCatalog);
  assert.deepEqual(
    tracks.map((track) => track.id),
    ["pale-page", "fire-escape", "clock-shop", "open-air"],
  );
  const pale = tracks[0];
  assert.ok(pale);
  assert.equal(pale.title, "Pale Page");
  assert.equal(pale.collection, "Deep Focus");
  assert.equal(pale.lane, "Focus");
  assert.equal(pale.bpm, null);
  assert.equal(pale.duration, 1320);
  assert.equal(pale.audioPath, "/assets/music-library/audio/pale-page.mp3");
  assert.equal(pale.thumbPath, "/assets/music-library/art/pale-page-400.jpg");
  assert.equal(pale.artPath, "/assets/music-library/art/pale-page-1200.jpg");
  assert.equal(tracks[1]?.bpm, 78.2);
  assert.equal(tracks[2]?.bpm, 86);
  assert.equal(tracks[2]?.lane, "Library");
  assert.equal(tracks[3]?.bpm, null);
  assert.equal(JSON.stringify(tracks).toLowerCase().includes("sonicrift"), false);
  assert.equal(JSON.stringify(tracks).includes("description"), false);
  assert.equal(mediaUrl(pale.audioPath), "https://matthewfinley.org/assets/music-library/audio/pale-page.mp3");
  assert.equal(mediaUrl("https://example.com/track.mp3"), null);
  assert.equal(mediaUrl("/assets/../secret.mp3"), null);
});

test("searches title, collection, and mood and filters by collection", () => {
  const tracks = decodeCatalog(liveCatalog);
  assert.deepEqual(
    filterCatalogTracks(tracks, "PALE", null).map((track) => track.id),
    ["pale-page"],
  );
  assert.deepEqual(
    filterCatalogTracks(tracks, "lamp hours", null).map((track) => track.id),
    ["fire-escape", "clock-shop"],
  );
  assert.deepEqual(
    filterCatalogTracks(tracks, "coastal", null).map((track) => track.id),
    ["open-air"],
  );
  assert.deepEqual(
    filterCatalogTracks(tracks, "shop", "Lamp Hours & early works").map((track) => track.id),
    ["clock-shop"],
  );
  assert.deepEqual(catalogCollections(tracks), ["Deep Focus", "Hotel of Tracks", "Lamp Hours & early works"]);
  assert.equal(trackBadge(tracks[1]!), "1:47 · 78 BPM");
  assert.equal(formatBpm(null), null);
  assert.equal(trackBadge(tracks[0]!), "22:00");
});

test("caches a normalized catalog and falls back to it when the network fails", async () => {
  let saved = "";
  const fresh = await resolveCatalog({
    fetchCatalog: async () => liveCatalog,
    readCache: async () => null,
    writeCache: async (text) => {
      saved = text;
    },
    now: new Date("2026-11-27T04:00:00Z"),
  });
  assert.equal(fresh.source, "network");
  assert.equal(fresh.tracks.length, 4);
  assert.equal(saved.toLowerCase().includes("sonicrift"), false);
  assert.equal(JSON.parse(saved).artist, CATALOG_ARTIST);

  const offline = await resolveCatalog({
    fetchCatalog: async () => {
      throw new Error("offline");
    },
    readCache: async () => saved,
    writeCache: async () => {
      throw new Error("should not write");
    },
  });
  assert.equal(offline.source, "cache");
  assert.equal(offline.tracks[0]?.id, "pale-page");

  const empty = await resolveCatalog({
    fetchCatalog: async () => {
      throw new Error("offline");
    },
    readCache: async () => null,
    writeCache: async () => undefined,
  });
  assert.deepEqual(empty, { tracks: [], source: "empty" });
});

test("keeps cache paths inside the app container and falls back to Dawn", () => {
  const documents = "file:///var/mobile/Containers/Data/Application/ABC/Documents/";
  assert.equal(librarySoundsPath(documents), "file:///var/mobile/Containers/Data/Application/ABC/Library/Sounds");
  assert.equal(librarySoundsPath("file:///data/user/0/app.jingle/files"), null);
  assert.equal(catalogJsonPath(documents), "file:///var/mobile/Containers/Data/Application/ABC/Documents/catalog/catalog.json");
  assert.equal(
    catalogAudioPath(documents, "Pale-Page"),
    "file:///var/mobile/Containers/Data/Application/ABC/Documents/catalog/audio/pale-page.mp3",
  );
  assert.equal(catalogAudioPath(documents, "../etc/passwd"), null);
  assert.equal(safeTrackId("sonicrift"), null);
  assert.equal(catalogWakeFilename("pale-page"), "catalog-pale-page.caf");
  assert.equal(
    wakeClipPath(documents, "pale-page"),
    "file:///var/mobile/Containers/Data/Application/ABC/Library/Sounds/catalog-pale-page.caf",
  );
  assert.equal(resolveNotificationSound({ sound: "dawn", catalogTrackId: "pale-page", clipReady: false }), "dawn.wav");
  assert.equal(resolveNotificationSound({ sound: "bell", catalogTrackId: "pale-page", clipReady: true }), "catalog-pale-page.caf");
  assert.equal(resolveNotificationSound({ sound: "machine", catalogTrackId: "pale-page", clipReady: true }), "machine.wav");
  assert.equal(resolveNotificationSound({ sound: "nope", catalogTrackId: null, clipReady: false }), "dawn.wav");
  assert.equal(resolveNotificationSound({ sound: "chime", catalogTrackId: "../x", clipReady: true }), "chime.wav");
});

test("serializes a catalog alarm and keeps bundled alarms compatible", () => {
  const legacy = sanitizeStore({
    version: 1,
    seeded: true,
    alarms: [
      {
        id: "morning",
        label: "Morning",
        hour: 6,
        minute: 0,
        repeat: [1, 2, 3, 4, 5],
        onceDate: null,
        sound: "bell",
        snoozeMinutes: 9,
        machineLeadMinutes: 0,
        enabled: true,
        createdAt: 1,
      },
    ],
    snoozes: [],
    settings: { theme: "night", autoBlank: true, bedsideDim: true },
  });
  assert.equal(legacy?.alarms[0]?.sound, "bell");
  assert.equal(legacy?.alarms[0]?.catalog, null);
  assert.equal(alarmToneName(legacy!.alarms[0]!), "Bell");

  const saved = sanitizeStore({
    version: 1,
    seeded: true,
    alarms: [
      {
        id: "catalog-alarm",
        label: "Morning",
        hour: 6,
        minute: 30,
        repeat: [],
        onceDate: "2026-11-28",
        sound: "dawn",
        catalog: {
          trackId: "pale-page",
          title: "Pale Page",
          collection: "Deep Focus",
          lane: "Focus",
          artist: "sonicrift",
          links: { Audiomack: "https://audiomack.com/sonicrift/song/pale-page-full" },
        },
        snoozeMinutes: 0,
        machineLeadMinutes: 0,
        enabled: true,
        createdAt: 2,
      },
    ],
    snoozes: [],
    settings: {},
  });
  const alarm = saved?.alarms[0];
  assert.ok(alarm);
  assert.deepEqual(alarm.catalog, {
    trackId: "pale-page",
    title: "Pale Page",
    collection: "Deep Focus",
    lane: "Focus",
  });
  assert.equal(alarm.sound, "dawn");
  assert.equal(alarmToneName(alarm), "Pale Page");
  const roundTrip = sanitizeStore(JSON.parse(JSON.stringify(saved)) as unknown);
  assert.deepEqual(roundTrip?.alarms[0]?.catalog, alarm.catalog);
  assert.equal(JSON.stringify(roundTrip).toLowerCase().includes("sonicrift"), false);

  const broken = sanitizeStore({
    version: 1,
    seeded: true,
    alarms: [
      {
        id: "bad",
        hour: 7,
        minute: 0,
        repeat: [],
        sound: "nope",
        catalog: { trackId: "../secret", title: "Nope", collection: "X", lane: "Y" },
        enabled: true,
      },
    ],
    snoozes: [],
    settings: {},
  });
  assert.equal(broken?.alarms[0]?.sound, "dawn");
  assert.equal(broken?.alarms[0]?.catalog, null);
  assert.equal(alarmToneName(broken!.alarms[0]!), "Dawn");

  const planned = planNotifications(
    [
      {
        ...alarm,
        repeat: [1],
        machineLeadMinutes: 10,
        enabled: true,
        onceDate: null,
      },
    ],
    [],
    new Date(2026, 10, 14, 12, 0, 0),
  );
  assert.equal(planned.find((item) => item.purpose === "alarm")?.catalogFile, "catalog-pale-page.caf");
  assert.equal(planned.find((item) => item.purpose === "machine")?.catalogFile, null);
  assert.equal(planned.find((item) => item.purpose === "machine")?.sound, "machine");
});

test("fades a wake clip in and out and writes a CAF iOS can read", () => {
  const sampleRate = 8000;
  const frames = 8000;
  assert.equal(frameGain(0, frames, sampleRate), 0);
  assert.equal(frameGain(4000, frames, sampleRate), 1);
  assert.ok(frameGain(frames - 1, frames, sampleRate) < 0.05);
  const samples = new Float32Array(frames);
  samples.fill(0.8);
  const caf = renderWakeClip({ sampleRate, channels: 1, samples }, 1);
  assert.ok(caf);
  assert.equal(Buffer.from(caf.subarray(0, 4)).toString("ascii"), "caff");
  const view = new DataView(caf.buffer, caf.byteOffset, caf.byteLength);
  assert.equal(view.getUint32(32, false), 2);
  const dataAt = caf.findIndex((_, index) => caf[index] === 100 && caf[index + 1] === 97 && caf[index + 2] === 116 && caf[index + 3] === 97);
  assert.ok(dataAt > 0);
  const first = view.getInt16(dataAt + 16, true);
  const middle = view.getInt16(dataAt + 16 + 4000 * 2, true);
  const last = view.getInt16(caf.byteLength - 2, true);
  assert.equal(first, 0);
  assert.ok(middle > 20000);
  assert.ok(Math.abs(last) < 1500);
  assert.equal(clipByteLength(1_000_000, 100, WAKE_CLIP_SECONDS), Math.ceil(1_000_000 * (29.25 / 100)) + 16384);
  assert.equal(clipByteLength(1000, 10, 28), 1000);
});

test("decodes an MP3 prefix into a wake clip", async () => {
  const bytes = new Uint8Array(readFileSync(fileURLToPath(new URL("./fixtures/sine.mp3", import.meta.url))));
  const pcm = await decodeMp3Clip(bytes, 2);
  assert.ok(pcm);
  assert.equal(pcm.sampleRate, 44100);
  assert.equal(pcm.channels, 1);
  assert.ok(pcm.samples.length > 44100 / 2);
  const caf = renderWakeClip(pcm, 1);
  assert.ok(caf);
  const path = join(tmpdir(), "jingle-wake-clip.caf");
  writeFileSync(path, caf);
  const probe = spawnSync(
    "ffprobe",
    ["-v", "error", "-show_entries", "stream=codec_name,sample_rate,channels", "-of", "json", path],
    { encoding: "utf8" },
  );
  if (probe.error || probe.status !== 0) return;
  const info = JSON.parse(probe.stdout) as { streams: { codec_name: string; sample_rate: string; channels: number }[] };
  assert.equal(info.streams[0]?.codec_name, "pcm_s16le");
  assert.equal(info.streams[0]?.sample_rate, "44100");
  assert.equal(info.streams[0]?.channels, 1);
});
