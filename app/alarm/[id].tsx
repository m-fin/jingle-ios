import { router, Stack, useLocalSearchParams } from "expo-router";
import { useEffect, useState } from "react";
import { Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { CatalogPicker } from "@/components/CatalogPicker";
import { Pill, pressCursor, Segment, StepButton } from "@/components/ui";
import type { CatalogTrack } from "@/src/lib/catalog";
import { bundledPreviewSource, previewSourceFor } from "@/src/lib/catalogDevice";
import { haptic } from "@/src/lib/haptics";
import { playSound, stopSound } from "@/src/lib/playback";
import { SOUND_LIST } from "@/src/lib/sounds";
import type { Alarm, SoundId } from "@/src/lib/types";
import { REPEAT_PRESETS, WEEKDAY_LETTERS, WEEKDAY_NAMES, repeatLabel, sameDays, to12, to24 } from "@/src/lib/time";
import { draftAlarm, useAlarms } from "@/src/state/alarms";
import { useTheme } from "@/src/state/theme";

function one(value: string | string[] | undefined): string {
  return Array.isArray(value) ? (value[0] ?? "") : (value ?? "");
}

export default function AlarmEditorScreen() {
  const insets = useSafeAreaInsets();
  const { colors, fonts } = useTheme();
  const params = useLocalSearchParams<{ id: string }>();
  const id = one(params.id);
  const isNew = id === "new";
  const { alarms, saveAlarm, deleteAlarm } = useAlarms();
  const existing = alarms.find((alarm) => alarm.id === id);
  const [draft, setDraft] = useState<Alarm | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [previewing, setPreviewing] = useState<string | null>(null);
  const [toneTab, setToneTab] = useState<"jingle" | "catalog">(existing?.catalogTone ? "catalog" : "jingle");

  useEffect(() => {
    if (draft) return;
    if (isNew) setDraft(draftAlarm());
    else if (existing) setDraft({ ...existing });
  }, [draft, existing, isNew]);

  useEffect(() => () => void stopSound(), []);

  if (!isNew && !existing && !draft) {
    return (
      <View style={{ flex: 1, backgroundColor: colors.bg, padding: 24, justifyContent: "center" }}>
        <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 22 }}>This alarm is gone.</Text>
        <View style={{ marginTop: 18 }}>
          <Pill label="Back to alarms" tone="quiet" onPress={() => router.back()} />
        </View>
      </View>
    );
  }

  if (!draft) return <View style={{ flex: 1, backgroundColor: colors.bg }} />;

  const { hour12, period } = to12(draft.hour);
  const setHour12 = (next: number) => {
    const wrapped = ((next - 1 + 12) % 12) + 1;
    setDraft({ ...draft, hour: to24(wrapped, period) });
  };
  const setMinute = (next: number) => {
    const wrapped = (next + 60) % 60;
    setDraft({ ...draft, minute: wrapped });
  };

  const previewBundled = (sound: SoundId) => {
    if (previewing === sound) {
      setPreviewing(null);
      void stopSound();
      return;
    }
    setPreviewing(sound);
    void playSound(bundledPreviewSource(sound), { volume: 0.85 });
  };

  const previewCatalog = (track: CatalogTrack) => {
    const key = `catalog:${track.id}`;
    if (previewing === key) {
      setPreviewing(null);
      void stopSound();
      return;
    }
    setPreviewing(key);
    void previewSourceFor(track).then((source) => playSound(source, { volume: 0.85, fadeInMs: 400 }));
  };

  const save = () => {
    const ok = saveAlarm(draft);
    if (!ok) return;
    void haptic("success");
    void stopSound();
    router.back();
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <Stack.Screen options={{ title: isNew ? "New alarm" : "Edit alarm" }} />
      <ScrollView
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ paddingHorizontal: 20, paddingTop: 8, paddingBottom: 24 }}
      >
        <TextInput
          testID="alarm-label"
          value={draft.label}
          onChangeText={(label) => setDraft({ ...draft, label })}
          placeholder="Name"
          placeholderTextColor={colors.faint}
          maxLength={40}
          accessibilityLabel="Alarm name"
          style={{
            color: colors.text,
            fontFamily: fonts.semibold,
            fontSize: 22,
            paddingVertical: 8,
          }}
        />

        <View style={{ alignItems: "center", marginTop: 12 }}>
          <Text style={{ color: colors.text, fontFamily: fonts.clock, fontSize: 64, fontVariant: ["tabular-nums"] }}>
            {String(hour12).padStart(2, "0")}:{String(draft.minute).padStart(2, "0")}
          </Text>
          <Text style={{ color: colors.muted, fontFamily: fonts.medium, letterSpacing: 1.4, marginTop: 2 }}>{period}</Text>
        </View>

        <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: 18, paddingHorizontal: 12 }}>
          <View style={{ alignItems: "center", gap: 10 }}>
            <StepButton glyph="+" accessibilityLabel="Later hour" onStep={() => setHour12(hour12 + 1)} />
            <Text style={{ color: colors.faint, fontFamily: fonts.medium, fontSize: 12 }}>Hour</Text>
            <StepButton glyph="−" accessibilityLabel="Earlier hour" onStep={() => setHour12(hour12 - 1)} />
          </View>
          <View style={{ alignItems: "center", gap: 10 }}>
            <StepButton glyph="+" accessibilityLabel="Later minute" onStep={() => setMinute(draft.minute + 1)} />
            <Text style={{ color: colors.faint, fontFamily: fonts.medium, fontSize: 12 }}>Minute</Text>
            <StepButton glyph="−" accessibilityLabel="Earlier minute" onStep={() => setMinute(draft.minute - 1)} />
          </View>
        </View>

        <View style={{ marginTop: 18 }}>
          <Segment
            value={period}
            onChange={(next) => setDraft({ ...draft, hour: to24(hour12, next) })}
            options={[
              { label: "AM", value: "AM" as const },
              { label: "PM", value: "PM" as const },
            ]}
          />
        </View>

        <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: 12 }}>
          {[0, 15, 30, 45].map((minute) => {
            const selected = draft.minute === minute;
            return (
              <Pressable
                key={minute}
                accessibilityRole="button"
                accessibilityLabel={`${minute} minutes`}
                onPress={() => {
                  void haptic("select");
                  setDraft({ ...draft, minute });
                }}
                style={[
                  pressCursor,
                  {
                    minWidth: 64,
                    minHeight: 36,
                    borderRadius: 18,
                    alignItems: "center",
                    justifyContent: "center",
                    backgroundColor: selected ? colors.orange : "transparent",
                    borderWidth: 1,
                    borderColor: selected ? colors.orange : colors.cardBorder,
                  },
                ]}
              >
                <Text style={{ color: selected ? colors.onOrange : colors.muted, fontFamily: fonts.medium }}>:{String(minute).padStart(2, "0")}</Text>
              </Pressable>
            );
          })}
        </View>

        <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 13, letterSpacing: 1.2, marginTop: 28 }}>REPEAT</Text>
        <View style={{ marginTop: 10 }}>
          <Segment
            value={REPEAT_PRESETS.find((preset) => sameDays(preset.days, draft.repeat))?.label ?? "custom"}
            onChange={(label) => {
              const preset = REPEAT_PRESETS.find((item) => item.label === label);
              if (!preset) return;
              setDraft({ ...draft, repeat: [...preset.days] });
            }}
            options={REPEAT_PRESETS.map((preset) => ({ label: preset.label === "Every day" ? "Daily" : preset.label, value: preset.label }))}
          />
        </View>
        <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: 14 }}>
          {WEEKDAY_LETTERS.map((letter, index) => {
            const selected = draft.repeat.includes(index);
            return (
              <Pressable
                key={`${letter}-${index}`}
                accessibilityRole="button"
                accessibilityLabel={WEEKDAY_NAMES[index]}
                accessibilityState={{ selected }}
                onPress={() => {
                  void haptic("select");
                  const repeat = selected ? draft.repeat.filter((day) => day !== index) : [...draft.repeat, index].sort((a, b) => a - b);
                  setDraft({ ...draft, repeat });
                }}
                style={[
                  pressCursor,
                  {
                    width: 40,
                    height: 40,
                    borderRadius: 20,
                    alignItems: "center",
                    justifyContent: "center",
                    backgroundColor: selected ? colors.orange : colors.card,
                    borderWidth: 1,
                    borderColor: selected ? colors.orange : colors.cardBorder,
                  },
                ]}
              >
                <Text style={{ color: selected ? colors.onOrange : colors.text, fontFamily: fonts.semibold }}>{letter}</Text>
              </Pressable>
            );
          })}
        </View>
        <Text style={{ color: colors.faint, fontFamily: fonts.body, fontSize: 14, marginTop: 8 }}>{repeatLabel(draft.repeat)}</Text>

        <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 13, letterSpacing: 1.2, marginTop: 28 }}>SOUND</Text>
        <View style={{ flexDirection: "row", gap: 8, marginTop: 10 }}>
          {(
            [
              { id: "jingle" as const, label: "Wake tones" },
              { id: "catalog" as const, label: "Matthew Finley Catalog" },
            ]
          ).map((tab) => {
            const selected = toneTab === tab.id;
            return (
              <Pressable
                key={tab.id}
                accessibilityRole="button"
                accessibilityState={{ selected }}
                onPress={() => {
                  void haptic("select");
                  setToneTab(tab.id);
                  setPreviewing(null);
                  void stopSound();
                }}
                style={[
                  pressCursor,
                  {
                    flex: 1,
                    minHeight: 48,
                    borderRadius: 16,
                    paddingHorizontal: 10,
                    alignItems: "center",
                    justifyContent: "center",
                    backgroundColor: selected ? colors.orange : colors.card,
                    borderWidth: 1,
                    borderColor: selected ? colors.orange : colors.cardBorder,
                  },
                ]}
              >
                <Text style={{ color: selected ? colors.onOrange : colors.text, fontFamily: fonts.medium, fontSize: 13, textAlign: "center" }}>
                  {tab.label}
                </Text>
              </Pressable>
            );
          })}
        </View>
        {toneTab === "jingle" ? (
          <View style={{ marginTop: 10, gap: 8 }}>
            {SOUND_LIST.map((sound) => {
              const selected = !draft.catalogTone && draft.sound === sound.id;
              return (
                <Pressable
                  key={sound.id}
                  accessibilityRole="button"
                  accessibilityState={{ selected }}
                  onPress={() => {
                    void haptic("select");
                    setDraft({ ...draft, sound: sound.id, catalogTone: null });
                    previewBundled(sound.id);
                  }}
                  style={[
                    pressCursor,
                    {
                      minHeight: 56,
                      borderRadius: 18,
                      paddingHorizontal: 16,
                      flexDirection: "row",
                      alignItems: "center",
                      justifyContent: "space-between",
                      backgroundColor: colors.card,
                      borderWidth: 1,
                      borderColor: selected ? colors.orange : colors.cardBorder,
                    },
                  ]}
                >
                  <View>
                    <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 16 }}>{sound.name}</Text>
                    <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 13, marginTop: 2 }}>{sound.detail}</Text>
                  </View>
                  <Text style={{ color: colors.orangeText, fontFamily: fonts.medium }}>{previewing === sound.id ? "Stop" : "Play"}</Text>
                </Pressable>
              );
            })}
          </View>
        ) : (
          <CatalogPicker
            selectedId={draft.catalogTone?.trackId ?? null}
            previewingId={previewing?.startsWith("catalog:") ? previewing.slice("catalog:".length) : null}
            onSelect={(track) => {
              setDraft({
                ...draft,
                sound: "dawn",
                catalogTone: { trackId: track.id, title: track.title, collection: track.collection },
              });
            }}
            onTogglePreview={previewCatalog}
          />
        )}

        <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 13, letterSpacing: 1.2, marginTop: 28 }}>SNOOZE</Text>
        <View style={{ marginTop: 10 }}>
          <Segment
            value={draft.snoozeMinutes}
            onChange={(snoozeMinutes) => setDraft({ ...draft, snoozeMinutes })}
            options={[
              { label: "Off", value: 0 as const },
              { label: "5", value: 5 as const },
              { label: "9", value: 9 as const },
              { label: "15", value: 15 as const },
            ]}
          />
        </View>

        <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 13, letterSpacing: 1.2, marginTop: 28 }}>MACHINE MODE</Text>
        <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 14, lineHeight: 20, marginTop: 6 }}>
          A quiet tone before the alarm. It is not a second wake time.
        </Text>
        <View style={{ marginTop: 10 }}>
          <Segment
            value={draft.machineLeadMinutes}
            onChange={(machineLeadMinutes) => setDraft({ ...draft, machineLeadMinutes })}
            options={[
              { label: "Off", value: 0 as const },
              { label: "10 min", value: 10 as const },
              { label: "20 min", value: 20 as const },
            ]}
          />
        </View>

        {!isNew ? (
          <Pressable
            accessibilityRole="button"
            onPress={() => {
              if (!confirmDelete) {
                setConfirmDelete(true);
                void haptic("warning");
                return;
              }
              deleteAlarm(draft.id);
              void stopSound();
              router.back();
            }}
            style={[pressCursor, { marginTop: 28, minHeight: 48, alignItems: "center", justifyContent: "center" }]}
          >
            <Text style={{ color: colors.danger, fontFamily: fonts.semibold, fontSize: 16 }}>
              {confirmDelete ? "Delete this alarm" : "Delete"}
            </Text>
          </Pressable>
        ) : null}
      </ScrollView>
      <View style={{ paddingHorizontal: 20, paddingTop: 8, paddingBottom: Math.max(insets.bottom, 16) }}>
        <Pill testID="save-alarm" label="Save alarm" onPress={save} />
      </View>
    </View>
  );
}
