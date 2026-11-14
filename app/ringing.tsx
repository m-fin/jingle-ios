import { router, useLocalSearchParams } from "expo-router";
import { useEffect, useRef, useState } from "react";
import { AccessibilityInfo, Animated, BackHandler, Platform, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { KeepAwake } from "@/components/KeepAwake";
import { Mark } from "@/components/Mark";
import { Pill } from "@/components/ui";
import { haptic } from "@/src/lib/haptics";
import { playSound, stopSound } from "@/src/lib/playback";
import { SOUNDS } from "@/src/lib/sounds";
import { clockParts } from "@/src/lib/time";
import { useAlarms } from "@/src/state/alarms";
import { useTheme } from "@/src/state/theme";

function one(value: string | string[] | undefined): string {
  return Array.isArray(value) ? (value[0] ?? "") : (value ?? "");
}

export default function RingingScreen() {
  const insets = useSafeAreaInsets();
  const { colors, fonts } = useTheme();
  const params = useLocalSearchParams<{ id?: string; purpose?: string; preview?: string }>();
  const id = one(params.id);
  const purpose = one(params.purpose) === "snooze" ? "snooze" : "alarm";
  const preview = one(params.preview) === "1";
  const { alarms, snoozeAlarm, dismissAlarm, claimRing, releaseRing } = useAlarms();
  const alarm = alarms.find((item) => item.id === id);
  const [now, setNow] = useState(() => new Date());
  const [reduceMotion, setReduceMotion] = useState(false);
  const pulse = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    claimRing();
    return () => releaseRing();
  }, [claimRing, releaseRing]);

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 250);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    let mounted = true;
    void AccessibilityInfo.isReduceMotionEnabled().then((value) => {
      if (mounted) setReduceMotion(value);
    });
    const sub = AccessibilityInfo.addEventListener("reduceMotionChanged", setReduceMotion);
    return () => {
      mounted = false;
      sub.remove();
    };
  }, []);

  useEffect(() => {
    if (reduceMotion) return;
    const loop = Animated.loop(
      Animated.timing(pulse, { toValue: 1, duration: 2200, useNativeDriver: Platform.OS !== "web" }),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse, reduceMotion]);

  useEffect(() => {
    if (preview || !alarm) return;
    void playSound(SOUNDS[alarm.sound].source, { loop: true, volume: 1 });
    const taps = setInterval(() => void haptic("heavy"), 1400);
    void haptic("heavy");
    return () => {
      clearInterval(taps);
      void stopSound();
    };
  }, [alarm, preview]);

  const leave = (action: "snooze" | "dismiss") => {
    if (!preview && alarm) {
      if (action === "snooze") snoozeAlarm(alarm.id);
      else dismissAlarm(alarm.id);
    } else {
      void stopSound();
    }
    if (router.canGoBack()) router.back();
    else router.replace("/");
  };

  useEffect(() => {
    const sub = BackHandler.addEventListener("hardwareBackPress", () => {
      leave("dismiss");
      return true;
    });
    return () => sub.remove();
  });

  const parts = clockParts(now);
  const label = alarm?.label ?? "Morning";
  const canSnooze = !preview && alarm ? alarm.snoozeMinutes > 0 : preview;
  const scale = pulse.interpolate({ inputRange: [0, 1], outputRange: [0.78, 1.28] });
  const opacity = pulse.interpolate({ inputRange: [0, 0.65, 1], outputRange: [0.55, 0.16, 0] });

  return (
    <View
      testID="ring-screen"
      style={{
        flex: 1,
        backgroundColor: colors.bg,
        paddingTop: Math.max(insets.top, 24),
        paddingBottom: Math.max(insets.bottom, 20),
        paddingHorizontal: 24,
        alignItems: "center",
      }}
    >
      <KeepAwake />
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
        <View style={{ width: 260, height: 260, alignItems: "center", justifyContent: "center" }}>
          <Animated.View
            pointerEvents="none"
            style={{
              position: "absolute",
              width: 210,
              height: 210,
              borderRadius: 105,
              borderWidth: 2,
              borderColor: colors.orange,
              opacity: reduceMotion ? 0.4 : opacity,
              transform: reduceMotion ? undefined : [{ scale }],
            }}
          />
          <Mark size={132} sun={colors.orange} pill={colors.ivory} glow={colors.glow} />
        </View>
        <Text style={{ color: colors.orangeText, fontFamily: fonts.semibold, letterSpacing: 1.8, marginTop: 8 }}>
          {purpose === "snooze" ? "SNOOZED" : "TIME TO GET UP"}
        </Text>
        <Text style={{ color: colors.text, fontFamily: fonts.clock, fontSize: 64, marginTop: 8, fontVariant: ["tabular-nums"] }}>
          {parts.hour}:{parts.minute}
        </Text>
        <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 22, marginTop: 8 }}>{label}</Text>
        {!alarm && !preview ? (
          <Text style={{ color: colors.muted, fontFamily: fonts.body, marginTop: 8 }}>This alarm is no longer set.</Text>
        ) : null}
      </View>
      <View style={{ width: "100%", gap: 12 }}>
        {canSnooze ? (
          <Pill
            testID="snooze-button"
            label={alarm ? `Snooze ${alarm.snoozeMinutes} min` : "Snooze"}
            tone="quiet"
            onPress={() => leave("snooze")}
          />
        ) : null}
        <Pill testID="dismiss-button" label="I'm up" onPress={() => leave("dismiss")} />
      </View>
    </View>
  );
}
