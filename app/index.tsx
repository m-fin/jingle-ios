import { router } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useEffect, useState } from "react";
import { AppState, Platform, Pressable, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { KeepAwake } from "@/components/KeepAwake";
import { Pill, pressCursor } from "@/components/ui";
import { dimScreen, restoreScreen } from "@/src/lib/bedside";
import { haptic } from "@/src/lib/haptics";
import { SOUNDS } from "@/src/lib/sounds";
import { BLANK_AFTER_MS } from "@/src/lib/types";
import { clockParts, dateLines, formatClock, nextUp, relativeRing, repeatLabel } from "@/src/lib/time";
import { useAlarms } from "@/src/state/alarms";
import { useTheme } from "@/src/state/theme";

function ClockGlow({ color }: { color: string }) {
  const layers = [
    { size: 360, opacity: 0.045 },
    { size: 270, opacity: 0.07 },
    { size: 190, opacity: 0.1 },
    { size: 110, opacity: 0.14 },
  ];
  return (
    <>
      {layers.map((layer) => (
        <View
          key={layer.size}
          pointerEvents="none"
          style={{
            position: "absolute",
            width: layer.size,
            height: layer.size,
            borderRadius: layer.size / 2,
            backgroundColor: color,
            opacity: layer.opacity,
          }}
        />
      ))}
    </>
  );
}

export default function ClockScreen() {
  const insets = useSafeAreaInsets();
  const { colors, fonts } = useTheme();
  const { alarms, snoozes, settings, permission, requestPermission } = useAlarms();
  const [now, setNow] = useState(() => new Date());
  const [blank, setBlank] = useState(false);
  const [activity, setActivity] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 250);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    if (!settings.autoBlank || blank || permission === "undetermined") return;
    const timer = setTimeout(() => setBlank(true), BLANK_AFTER_MS);
    return () => clearTimeout(timer);
  }, [activity, blank, permission, settings.autoBlank]);

  useEffect(() => {
    if (Platform.OS === "web") return;
    if (!settings.bedsideDim) {
      void restoreScreen();
      return;
    }
    const level = blank ? 0.02 : 0.34;
    void dimScreen(level);
    const sub = AppState.addEventListener("change", (state) => {
      if (state === "active") void dimScreen(level);
      else void restoreScreen();
    });
    return () => {
      sub.remove();
      void restoreScreen();
    };
  }, [blank, settings.bedsideDim]);

  const parts = clockParts(now);
  const date = dateLines(now);
  const upcoming = nextUp(alarms, snoozes, now);
  const colonOn = now.getSeconds() % 2 === 0;

  if (blank) {
    return (
      <Pressable
        testID="blank-screen"
        accessibilityRole="button"
        accessibilityLabel="Display is off. Tap to show the clock."
        onPress={() => {
          void haptic("light");
          setBlank(false);
          setActivity((value) => value + 1);
        }}
        style={{ flex: 1, backgroundColor: "#000000" }}
      >
        <StatusBar hidden />
        <KeepAwake />
      </Pressable>
    );
  }

  return (
    <View
      testID="clock-screen"
      style={{ flex: 1, backgroundColor: colors.bg, paddingTop: Math.max(insets.top, 18), paddingBottom: Math.max(insets.bottom, 18) }}
      onStartShouldSetResponderCapture={() => {
        setActivity((value) => value + 1);
        return false;
      }}
    >
      <KeepAwake />
      <View style={{ paddingHorizontal: 24, alignItems: "flex-end" }}>
        <Pressable
          testID="settings-button"
          accessibilityRole="button"
          accessibilityLabel="Settings"
          onPress={() => {
            void haptic("light");
            router.push("/settings");
          }}
          hitSlop={12}
          style={pressCursor}
        >
          <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 15 }}>Settings</Text>
        </Pressable>
      </View>

      <View style={{ alignItems: "center", marginTop: 28 }}>
        <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 13, letterSpacing: 3.4 }}>{date.weekday}</Text>
        <Text style={{ color: colors.text, fontFamily: fonts.body, fontSize: 20, marginTop: 6 }}>{date.day}</Text>
      </View>

      <View style={{ alignItems: "center", justifyContent: "center", marginTop: 18, minHeight: 180 }}>
        {upcoming ? <ClockGlow color={colors.orange} /> : null}
        <View style={{ flexDirection: "row", alignItems: "flex-end", justifyContent: "center" }}>
          <Text
            testID="clock-time"
            maxFontSizeMultiplier={1.15}
            style={{ color: colors.text, fontFamily: fonts.clock, fontSize: 92, lineHeight: 100, letterSpacing: -2, fontVariant: ["tabular-nums"] }}
          >
            {parts.hour}
            <Text style={{ opacity: colonOn ? 1 : 0.35 }}>:</Text>
            {parts.minute}
          </Text>
          <Text
            style={{
              color: colors.muted,
              fontFamily: fonts.medium,
              fontSize: 18,
              marginLeft: 8,
              marginBottom: 18,
              fontVariant: ["tabular-nums"],
            }}
          >
            {parts.second}
          </Text>
        </View>
        <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 16, letterSpacing: 1.5, marginTop: 2 }}>{parts.period}</Text>
        <Text style={{ color: colors.faint, fontFamily: fonts.body, fontSize: 13, marginTop: 14 }}>Synced to this iPhone</Text>
      </View>

      <Pressable
        testID="alarm-card"
        accessibilityRole="button"
        accessibilityLabel={upcoming ? `Next alarm ${formatClock(upcoming.alarm.hour, upcoming.alarm.minute)}` : "No alarm set"}
        onPress={() => {
          if (!upcoming) {
            router.push("/alarms");
            return;
          }
          router.push(`/alarm/${upcoming.alarm.id}`);
        }}
        style={[
          pressCursor,
          {
            marginHorizontal: 24,
            marginTop: 28,
            backgroundColor: colors.card,
            borderRadius: 28,
            borderWidth: 1,
            borderColor: colors.cardBorder,
            paddingHorizontal: 22,
            paddingVertical: 18,
          },
        ]}
      >
        <Text style={{ color: upcoming ? colors.orangeText : colors.muted, fontFamily: fonts.semibold, fontSize: 13, letterSpacing: 1.6 }}>
          {upcoming?.kind === "snooze" ? "SNOOZED" : upcoming ? "ALARM  ·  ON" : "ALARM  ·  OFF"}
        </Text>
        <Text style={{ color: colors.text, fontFamily: fonts.clock, fontSize: 32, marginTop: 8 }}>
          {upcoming ? formatClock(upcoming.kind === "snooze" ? upcoming.when.getHours() : upcoming.alarm.hour, upcoming.kind === "snooze" ? upcoming.when.getMinutes() : upcoming.alarm.minute) : "No wake time"}
        </Text>
        <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 15, marginTop: 4 }}>
          {upcoming
            ? `${upcoming.alarm.label}  ·  ${upcoming.kind === "snooze" ? "Snoozing" : repeatLabel(upcoming.alarm.repeat)}  ·  ${SOUNDS[upcoming.alarm.sound].name}`
            : "Add one when you want the morning."}
        </Text>
        {upcoming ? <Text style={{ color: colors.faint, fontFamily: fonts.medium, fontSize: 13, marginTop: 10 }}>{relativeRing(upcoming.when, now)}</Text> : null}
      </Pressable>

      <View style={{ flex: 1 }} />

      {permission !== "granted" ? (
        <View
          style={{
            marginHorizontal: 24,
            marginBottom: 14,
            backgroundColor: colors.card,
            borderRadius: 22,
            borderWidth: 1,
            borderColor: colors.cardBorder,
            padding: 16,
          }}
        >
          <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 16 }}>Ring when the phone is locked</Text>
          <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 14, lineHeight: 20, marginTop: 6 }}>
            {Platform.OS === "web"
              ? "On iPhone, notifications wake you after the screen locks. This preview rings while the tab stays open."
              : permission === "denied"
                ? "Notifications are off, so a locked iPhone stays quiet. Jingle can still ring while this clock is open."
                : "Allow notifications and Jingle can wake you after the screen turns off."}
          </Text>
          {permission !== "denied" ? (
            <View style={{ marginTop: 12 }}>
              <Pill label="Allow notifications" onPress={() => void requestPermission()} />
            </View>
          ) : null}
        </View>
      ) : null}

      <View style={{ flexDirection: "row", gap: 12, paddingHorizontal: 24 }}>
        <View style={{ flex: 1 }}>
          <Pill testID="alarms-button" label="Alarms" tone="quiet" onPress={() => router.push("/alarms")} />
        </View>
        <View style={{ flex: 1 }}>
          <Pill testID="blank-button" label="Dark" tone="ghost" onPress={() => setBlank(true)} />
        </View>
      </View>
    </View>
  );
}
