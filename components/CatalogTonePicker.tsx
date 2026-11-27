import { useEffect, useMemo, useRef, useState } from "react";
import { Image, Pressable, ScrollView, Text, TextInput, View } from "react-native";

import { pressCursor } from "@/components/ui";
import { catalogCollections, filterCatalogTracks, mediaUrl, trackBadge, type CatalogTrack } from "@/src/lib/catalog";
import { loadMatthewFinleyCatalog, prepareCatalogWake, type DownloadPhase } from "@/src/lib/catalogFiles";
import { localCatalogAudioUri, wakeClipReady } from "@/src/lib/catalogPlayback";
import { haptic } from "@/src/lib/haptics";
import { CATALOG_ARTIST, catalogWakeFilename } from "@/src/lib/tone";
import { useTheme } from "@/src/state/theme";

type DownloadState = { phase: DownloadPhase | "audio"; progress: number };

const VISIBLE_LIMIT = 60;

function readyNow(trackId: string): boolean {
  const filename = catalogWakeFilename(trackId);
  return Boolean(localCatalogAudioUri(trackId) && filename && wakeClipReady(filename));
}

export function CatalogTonePicker({
  selectedId,
  previewId,
  onSelect,
  onPreview,
}: {
  selectedId: string | null;
  previewId: string | null;
  onSelect: (track: CatalogTrack) => void;
  onPreview: (track: CatalogTrack) => void;
}) {
  const { colors, fonts } = useTheme();
  const [tracks, setTracks] = useState<CatalogTrack[]>([]);
  const [status, setStatus] = useState<"loading" | "ready" | "offline" | "empty">("loading");
  const [query, setQuery] = useState("");
  const [collection, setCollection] = useState<string | null>(null);
  const [downloads, setDownloads] = useState<Record<string, DownloadState>>({});
  const inflight = useRef(new Set<string>());

  useEffect(() => {
    let cancelled = false;
    void loadMatthewFinleyCatalog().then((result) => {
      if (cancelled) return;
      setTracks(result.tracks);
      setStatus(result.source === "empty" ? "empty" : result.source === "cache" ? "offline" : "ready");
    });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!selectedId || downloads[selectedId] || !readyNow(selectedId)) return;
    setDownloads((current) => ({ ...current, [selectedId]: { phase: "ready", progress: 1 } }));
  }, [downloads, selectedId]);

  const collections = useMemo(() => catalogCollections(tracks), [tracks]);
  const filtered = useMemo(() => filterCatalogTracks(tracks, query, collection), [collection, query, tracks]);
  const visible = filtered.slice(0, VISIBLE_LIMIT);

  const choose = (track: CatalogTrack) => {
    void haptic("select");
    onSelect(track);
    if (inflight.current.has(track.id) || readyNow(track.id)) {
      if (readyNow(track.id)) setDownloads((current) => ({ ...current, [track.id]: { phase: "ready", progress: 1 } }));
      return;
    }
    inflight.current.add(track.id);
    setDownloads((current) => ({ ...current, [track.id]: { phase: "downloading", progress: 0 } }));
    void prepareCatalogWake(track, (phase, progress) => {
      setDownloads((current) => ({ ...current, [track.id]: { phase, progress } }));
    }).then((result) => {
      inflight.current.delete(track.id);
      setDownloads((current) => ({
        ...current,
        [track.id]:
          result === "ready"
            ? { phase: "ready", progress: 1 }
            : result === "audio"
              ? { phase: "audio", progress: 1 }
              : { phase: "error", progress: 0 },
      }));
    });
  };

  return (
    <View style={{ marginTop: 10 }}>
      <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 16 }}>{CATALOG_ARTIST}</Text>
      <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 13, lineHeight: 18, marginTop: 4 }}>
        {tracks.length > 0 ? `${tracks.length} tracks. Saved on this iPhone after you pick one.` : "Public catalog. Jingle tones stay available offline."}
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
          marginTop: 12,
          minHeight: 44,
          borderRadius: 14,
          paddingHorizontal: 14,
          color: colors.text,
          backgroundColor: colors.card,
          borderWidth: 1,
          borderColor: colors.cardBorder,
          fontFamily: fonts.body,
          fontSize: 16,
        }}
      />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginTop: 10, flexGrow: 0 }} contentContainerStyle={{ gap: 8, paddingRight: 8 }}>
        {["All", ...collections].map((item) => {
          const selected = item === "All" ? collection === null : collection === item;
          return (
            <Pressable
              key={item}
              accessibilityRole="button"
              accessibilityState={{ selected }}
              accessibilityLabel={item === "All" ? "All collections" : item}
              onPress={() => {
                void haptic("select");
                setCollection(item === "All" ? null : item);
              }}
              style={[
                pressCursor,
                {
                  minHeight: 34,
                  borderRadius: 17,
                  paddingHorizontal: 12,
                  alignItems: "center",
                  justifyContent: "center",
                  backgroundColor: selected ? colors.orange : colors.card,
                  borderWidth: 1,
                  borderColor: selected ? colors.orange : colors.cardBorder,
                },
              ]}
            >
              <Text style={{ color: selected ? colors.onOrange : colors.muted, fontFamily: fonts.medium, fontSize: 13 }}>{item}</Text>
            </Pressable>
          );
        })}
      </ScrollView>
      {status === "loading" ? (
        <Text style={{ color: colors.muted, fontFamily: fonts.body, marginTop: 16 }}>Loading the catalog…</Text>
      ) : null}
      {status === "empty" ? (
        <Text style={{ color: colors.muted, fontFamily: fonts.body, marginTop: 16, lineHeight: 20 }}>
          The catalog didn’t load. Jingle tones still ring, and this tries again when you’re connected.
        </Text>
      ) : null}
      {status === "offline" ? (
        <Text style={{ color: colors.faint, fontFamily: fonts.body, fontSize: 13, marginTop: 8 }}>Showing the saved catalog.</Text>
      ) : null}
      <ScrollView nestedScrollEnabled keyboardShouldPersistTaps="handled" style={{ marginTop: 12, height: 440 }} contentContainerStyle={{ gap: 8, paddingBottom: 8 }}>
        {visible.map((item) => {
          const selected = item.id === selectedId;
          const download = downloads[item.id];
          const art = mediaUrl(item.thumbPath);
          const percent = download?.phase === "downloading" ? `${Math.round(download.progress * 100)}%` : null;
          const mark =
            download?.phase === "ready"
              ? "✓"
              : download?.phase === "preparing"
                ? "Preparing"
                : download?.phase === "audio"
                  ? "In app"
                  : download?.phase === "error"
                    ? "Still needs a download"
                    : percent;
          return (
            <View
              key={item.id}
              style={{
                minHeight: 76,
                borderRadius: 18,
                paddingHorizontal: 12,
                paddingVertical: 10,
                flexDirection: "row",
                alignItems: "center",
                gap: 10,
                backgroundColor: colors.card,
                borderWidth: 1,
                borderColor: selected ? colors.orange : colors.cardBorder,
              }}
            >
              <Pressable
                accessibilityRole="button"
                accessibilityState={{ selected }}
                accessibilityLabel={`${item.title}, ${CATALOG_ARTIST}, ${item.collection}`}
                onPress={() => choose(item)}
                style={[pressCursor, { flex: 1, flexDirection: "row", alignItems: "center", gap: 10 }]}
              >
                {art ? (
                  <Image source={{ uri: art }} accessibilityIgnoresInvertColors style={{ width: 52, height: 52, borderRadius: 10, backgroundColor: colors.bg }} />
                ) : (
                  <View style={{ width: 52, height: 52, borderRadius: 10, backgroundColor: colors.bg }} />
                )}
                <View style={{ flex: 1 }}>
                  <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 16 }} numberOfLines={1}>
                    {item.title}
                  </Text>
                  <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 13, marginTop: 2 }} numberOfLines={1}>
                    {item.collection}
                    {item.lane ? ` · ${item.lane}` : ""}
                  </Text>
                  <Text style={{ color: mark === "✓" ? colors.orangeText : colors.faint, fontFamily: fonts.medium, fontSize: 12, marginTop: 3 }}>
                    {trackBadge(item)}
                    {mark ? `  ${mark}` : ""}
                  </Text>
                </View>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={previewId === item.id ? `Stop ${item.title}` : `Play ${item.title}`}
                onPress={() => onPreview(item)}
                style={[pressCursor, { minWidth: 52, minHeight: 44, alignItems: "center", justifyContent: "center" }]}
              >
                <Text style={{ color: colors.orangeText, fontFamily: fonts.medium }}>{previewId === item.id ? "Stop" : "Play"}</Text>
              </Pressable>
            </View>
          );
        })}
        {filtered.length > visible.length ? (
          <Text style={{ color: colors.faint, fontFamily: fonts.body, fontSize: 13, marginTop: 8 }}>
            Showing {visible.length} of {filtered.length}. Keep typing to narrow the list.
          </Text>
        ) : null}
      </ScrollView>
    </View>
  );
}
