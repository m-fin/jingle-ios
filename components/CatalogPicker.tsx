import { useEffect, useMemo, useState } from "react";
import { Image, Platform, Pressable, ScrollView, Text, TextInput, View } from "react-native";

import { pressCursor } from "@/components/ui";
import {
  bpmBadge,
  CATALOG_ARTIST,
  filterCatalog,
  formatBytes,
  formatDuration,
  listCollections,
  type CatalogTrack,
} from "@/src/lib/catalog";
import { ensureCatalogTrack, loadDeviceCatalog, trackCacheStatus, type TrackCacheStatus } from "@/src/lib/catalogDevice";
import { haptic } from "@/src/lib/haptics";
import { useTheme } from "@/src/state/theme";

type RowStatus = TrackCacheStatus & { progress: number | null; failed: boolean };

type Props = {
  selectedId: string | null;
  previewingId: string | null;
  onSelect: (track: CatalogTrack) => void;
  onTogglePreview: (track: CatalogTrack) => void;
};

export function CatalogPicker({ selectedId, previewingId, onSelect, onTogglePreview }: Props) {
  const { colors, fonts } = useTheme();
  const [tracks, setTracks] = useState<CatalogTrack[]>([]);
  const [query, setQuery] = useState("");
  const [collection, setCollection] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [offline, setOffline] = useState(false);
  const [limit, setLimit] = useState(24);
  const [status, setStatus] = useState<Record<string, RowStatus>>({});

  useEffect(() => {
    let live = true;
    void loadDeviceCatalog((next) => {
      if (live) setTracks(next);
    })
      .then((result) => {
        if (live) setOffline(result.offline);
      })
      .catch(() => {
        if (live) setError("Couldn't reach the Matthew Finley catalog.");
      });
    return () => {
      live = false;
    };
  }, []);

  useEffect(() => {
    if (!selectedId) return;
    let live = true;
    void trackCacheStatus(selectedId).then((next) => {
      if (!live) return;
      setStatus((prev) => ({ ...prev, [selectedId]: { ...next, progress: null, failed: false } }));
    });
    return () => {
      live = false;
    };
  }, [selectedId]);

  useEffect(() => {
    setLimit(24);
  }, [query, collection]);

  const filtered = useMemo(() => filterCatalog(tracks, query, collection), [tracks, query, collection]);
  const collections = useMemo(() => listCollections(tracks), [tracks]);
  const visible = filtered.slice(0, limit);
  const selected = tracks.find((track) => track.id === selectedId) ?? null;

  const save = (track: CatalogTrack) => {
    setStatus((prev) => ({
      ...prev,
      [track.id]: { audioReady: false, clipReady: false, progress: prev[track.id]?.progress ?? 0, failed: false },
    }));
    void ensureCatalogTrack(track, (ratio) => {
      setStatus((prev) => ({
        ...prev,
        [track.id]: { audioReady: false, clipReady: false, progress: ratio, failed: false },
      }));
    }).then((next) => {
      setStatus((prev) => ({ ...prev, [track.id]: { ...next, progress: null, failed: !next.audioReady } }));
    });
  };

  const badge = (track: CatalogTrack) => {
    const parts = [formatDuration(track.duration), bpmBadge(track), formatBytes(track.bytes)].filter(Boolean);
    return parts.join("  ·  ");
  };

  const readiness = (trackId: string) => {
    const row = status[trackId];
    if (!row) return null;
    if (row.progress != null && !row.audioReady) return `Saving ${Math.round(row.progress * 100)}%`;
    if (row.clipReady) return "Ready offline";
    if (row.audioReady) return "Saved in the app";
    if (row.failed) return "Alarm uses Dawn";
    return null;
  };

  return (
    <View style={{ marginTop: 10, gap: 10 }}>
      <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 14, lineHeight: 20 }}>
        {CATALOG_ARTIST}. Search the catalog, then save a track on this phone. A locked iPhone plays a short wake clip. If that
        file is missing, the alarm uses Dawn.
      </Text>
      <TextInput
        testID="catalog-search"
        value={query}
        onChangeText={setQuery}
        placeholder="Search title, collection, or mood"
        placeholderTextColor={colors.faint}
        autoCorrect={false}
        autoCapitalize="none"
        accessibilityLabel="Search the Matthew Finley catalog"
        style={{
          color: colors.text,
          fontFamily: fonts.body,
          fontSize: 16,
          minHeight: 48,
          borderRadius: 16,
          paddingHorizontal: 14,
          backgroundColor: colors.card,
          borderWidth: 1,
          borderColor: colors.cardBorder,
        }}
      />
      {collections.length > 0 ? (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8, paddingRight: 8 }}>
          <CollectionChip label="All" selected={collection == null} onPress={() => setCollection(null)} />
          {collections.map((item) => (
            <CollectionChip
              key={item.id}
              label={item.title}
              selected={collection === item.id}
              onPress={() => setCollection(item.id)}
            />
          ))}
        </ScrollView>
      ) : null}
      {offline && tracks.length > 0 ? (
        <Text style={{ color: colors.faint, fontFamily: fonts.body, fontSize: 13 }}>
          Couldn't refresh. These tracks are saved with Jingle.
        </Text>
      ) : null}
      {error && tracks.length === 0 ? (
        <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 15 }}>{error}</Text>
      ) : null}
      {!error && tracks.length === 0 ? (
        <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 15 }}>Loading the catalog…</Text>
      ) : null}
      {selected && !visible.some((track) => track.id === selected.id) ? (
        <TrackRow
          track={selected}
          selected
          previewing={previewingId === selected.id}
          detail={readiness(selected.id) ?? badge(selected)}
          onPress={() => {
            void haptic("select");
            onSelect(selected);
            save(selected);
          }}
          onPreview={() => onTogglePreview(selected)}
        />
      ) : null}
      <View style={{ gap: 8 }}>
        {visible.map((track) => {
          const note = readiness(track.id);
          return (
            <TrackRow
              key={track.id}
              track={track}
              selected={track.id === selectedId}
              previewing={previewingId === track.id}
              detail={note ?? `${CATALOG_ARTIST}${track.collection ? `  ·  ${track.collection}` : ""}${track.lane ? `  ·  ${track.lane}` : ""}`}
              meta={note ? badge(track) : badge(track)}
              onPress={() => {
                void haptic("select");
                onSelect(track);
                save(track);
              }}
              onPreview={() => onTogglePreview(track)}
            />
          );
        })}
      </View>
      {filtered.length > visible.length ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Show more tracks"
          onPress={() => setLimit((value) => value + 24)}
          style={[pressCursor, { minHeight: 44, alignItems: "center", justifyContent: "center" }]}
        >
          <Text style={{ color: colors.orangeText, fontFamily: fonts.medium }}>Show more</Text>
        </Pressable>
      ) : null}
      {tracks.length > 0 && filtered.length === 0 ? (
        <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 15 }}>No tracks match that search.</Text>
      ) : null}
    </View>
  );
}

function CollectionChip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  const { colors, fonts } = useTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      onPress={() => {
        void haptic("select");
        onPress();
      }}
      style={[
        pressCursor,
        {
          minHeight: 36,
          paddingHorizontal: 12,
          borderRadius: 18,
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: selected ? colors.orange : colors.card,
          borderWidth: 1,
          borderColor: selected ? colors.orange : colors.cardBorder,
        },
      ]}
    >
      <Text style={{ color: selected ? colors.onOrange : colors.text, fontFamily: fonts.medium, fontSize: 13 }}>{label}</Text>
    </Pressable>
  );
}

function TrackRow({
  track,
  selected,
  previewing,
  detail,
  meta,
  onPress,
  onPreview,
}: {
  track: CatalogTrack;
  selected: boolean;
  previewing: boolean;
  detail: string;
  meta?: string;
  onPress: () => void;
  onPreview: () => void;
}) {
  const { colors, fonts } = useTheme();
  const ready = detail === "Ready offline";
  return (
    <View
      testID={`catalog-track-${track.id}`}
      style={{
        minHeight: 72,
        borderRadius: 18,
        paddingHorizontal: 12,
        paddingVertical: 10,
        flexDirection: "row",
        alignItems: "center",
        gap: 12,
        backgroundColor: colors.card,
        borderWidth: 1,
        borderColor: selected ? colors.orange : colors.cardBorder,
      }}
    >
      <Pressable
        accessibilityRole="button"
        accessibilityState={{ selected }}
        accessibilityLabel={`${track.title}, ${CATALOG_ARTIST}`}
        onPress={onPress}
        style={[pressCursor, { flex: 1, flexDirection: "row", alignItems: "center", gap: 12 }]}
      >
        <Cover track={track} />
        <View style={{ flex: 1 }}>
          <Text numberOfLines={1} style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 16 }}>
            {track.title}
          </Text>
          <Text numberOfLines={1} style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 13, marginTop: 2 }}>
            {detail}
          </Text>
          {meta ? (
            <Text numberOfLines={1} style={{ color: colors.faint, fontFamily: fonts.medium, fontSize: 12, marginTop: 2 }}>
              {meta}
            </Text>
          ) : null}
        </View>
      </Pressable>
      <View style={{ alignItems: "flex-end", gap: 4 }}>
        {ready ? <Text style={{ color: colors.orangeText, fontFamily: fonts.semibold, fontSize: 16 }}>✓</Text> : null}
        <Pressable
          testID={`catalog-play-${track.id}`}
          accessibilityRole="button"
          accessibilityLabel={previewing ? `Stop ${track.title}` : `Play ${track.title}`}
          hitSlop={8}
          onPress={onPreview}
          style={pressCursor}
        >
          <Text style={{ color: colors.orangeText, fontFamily: fonts.medium }}>{previewing ? "Stop" : "Play"}</Text>
        </Pressable>
      </View>
    </View>
  );
}

function Cover({ track }: { track: CatalogTrack }) {
  const { colors, fonts } = useTheme();
  const [failed, setFailed] = useState(false);
  const letter = (
    <View style={{ width: 52, height: 52, borderRadius: 10, backgroundColor: colors.switchOff, alignItems: "center", justifyContent: "center" }}>
      <Text style={{ color: colors.text, fontFamily: fonts.semibold }}>{track.title.slice(0, 1)}</Text>
    </View>
  );
  // The catalog host sends Cross-Origin-Resource-Policy: same-origin, so a browser preview cannot paint the files.
  if (Platform.OS === "web" || !track.thumbUrl || failed) return letter;
  return (
    <Image
      source={{ uri: track.thumbUrl }}
      accessibilityIgnoresInvertColors
      onError={() => setFailed(true)}
      style={{ width: 52, height: 52, borderRadius: 10, backgroundColor: colors.switchOff }}
    />
  );
}
