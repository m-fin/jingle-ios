import Constants from "expo-constants";
import { router } from "expo-router";
import { Linking, Platform, ScrollView, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { Mark } from "@/components/Mark";
import { Pill, Segment, Switch } from "@/components/ui";
import { APP_VERSION, BUNDLE_ID, privacyPolicyUrl } from "@/src/lib/release";
import { useAlarms } from "@/src/state/alarms";
import { useTheme } from "@/src/state/theme";
import type { ThemeChoice } from "@/src/lib/types";

export default function SettingsScreen() {
  const insets = useSafeAreaInsets();
  const { colors, fonts } = useTheme();
  const { settings, updateSettings, permission, requestPermission, refreshPermission } = useAlarms();

  const permissionLabel = permission === "granted" ? "On" : permission === "denied" ? "Off" : "Not asked";
  const version = Constants.expoConfig?.version ?? APP_VERSION;
  const bundleId = Constants.expoConfig?.ios?.bundleIdentifier ?? BUNDLE_ID;
  const publicPolicy = privacyPolicyUrl(process.env.EXPO_PUBLIC_PRIVACY_POLICY_URL);

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ paddingHorizontal: 20, paddingTop: 8, paddingBottom: Math.max(insets.bottom, 32) }}
    >
      <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 13, letterSpacing: 1.2 }}>APPEARANCE</Text>
      <View style={{ marginTop: 10 }}>
        <Segment
          value={settings.theme}
          onChange={(theme: ThemeChoice) => updateSettings({ theme })}
          options={[
            { label: "Night", value: "night" },
            { label: "Day", value: "day" },
            { label: "Match", value: "system" },
          ]}
        />
      </View>
      <Text style={{ color: colors.faint, fontFamily: fonts.body, fontSize: 14, lineHeight: 20, marginTop: 8 }}>
        Night is the bedside face. Day is a warm paper clock for when you are already up.
      </Text>

      <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 13, letterSpacing: 1.2, marginTop: 28 }}>BEDSIDE</Text>
      <View
        style={{
          marginTop: 10,
          backgroundColor: colors.card,
          borderRadius: 20,
          borderWidth: 1,
          borderColor: colors.cardBorder,
          paddingHorizontal: 16,
        }}
      >
        <View style={{ minHeight: 64, flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
          <View style={{ flex: 1 }}>
            <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 16 }}>Blank the display</Text>
            <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 13, marginTop: 2 }}>Goes fully dark after a quiet moment.</Text>
          </View>
          <Switch label="Blank the display" value={settings.autoBlank} onValueChange={(autoBlank) => updateSettings({ autoBlank })} />
        </View>
        <View style={{ height: 1, backgroundColor: colors.cardBorder }} />
        <View style={{ minHeight: 64, flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
          <View style={{ flex: 1 }}>
            <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 16 }}>Dim the screen</Text>
            <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 13, marginTop: 2 }}>Lowers brightness on the clock, then restores it.</Text>
          </View>
          <Switch label="Dim the screen" value={settings.bedsideDim} onValueChange={(bedsideDim) => updateSettings({ bedsideDim })} />
        </View>
      </View>

      <Text style={{ color: colors.muted, fontFamily: fonts.medium, fontSize: 13, letterSpacing: 1.2, marginTop: 28 }}>NOTIFICATIONS</Text>
      <View
        style={{
          marginTop: 10,
          backgroundColor: colors.card,
          borderRadius: 20,
          borderWidth: 1,
          borderColor: colors.cardBorder,
          padding: 16,
          gap: 12,
        }}
      >
        <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 16 }}>Status · {permissionLabel}</Text>
        <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 14, lineHeight: 20 }}>
          Jingle schedules the alarm on this iPhone. Leave the clock open and it rings here, even with the silent switch on. Once the phone locks,
          iOS plays the notification sound and the silent switch can mute it. Apple only lets approved Critical Alerts ring through that switch.
        </Text>
        {permission === "granted" ? (
          <Pill label="Check again" tone="quiet" onPress={() => void refreshPermission()} />
        ) : (
          <Pill
            label={permission === "denied" && Platform.OS !== "web" ? "Open iPhone Settings" : "Allow notifications"}
            onPress={() => {
              if (permission === "denied" && Platform.OS !== "web") void Linking.openSettings();
              else void requestPermission();
            }}
          />
        )}
      </View>

      <View style={{ alignItems: "center", marginTop: 40 }}>
        <Mark size={72} sun={colors.orange} pill={colors.ivory} glow={colors.glow} />
        <Text style={{ color: colors.text, fontFamily: fonts.clock, fontSize: 36, marginTop: 8 }}>Jingle</Text>
        <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 15, marginTop: 4, textAlign: "center" }}>
          Your wake up morning companion.
        </Text>
        <Text style={{ color: colors.faint, fontFamily: fonts.body, fontSize: 13, marginTop: 14, textAlign: "center", lineHeight: 19 }}>
          Designed by Matthew Finley. Bundled wake tones are original. A catalog track is saved on this phone.
        </Text>
        <Text style={{ color: colors.faint, fontFamily: fonts.medium, fontSize: 13, marginTop: 8, textAlign: "center" }}>
          Version {version} · {bundleId}
        </Text>
        <Text
          testID="privacy-link"
          accessibilityRole="link"
          onPress={() => router.push("/privacy")}
          style={{ color: colors.orangeText, fontFamily: fonts.medium, fontSize: 15, marginTop: 16 }}
        >
          Privacy policy
        </Text>
        {publicPolicy ? (
          <Text
            accessibilityRole="link"
            onPress={() => void Linking.openURL(publicPolicy)}
            style={{ color: colors.orangeText, fontFamily: fonts.medium, fontSize: 15, marginTop: 12, textAlign: "center" }}
          >
            Privacy policy on the web
          </Text>
        ) : null}
        <Text style={{ color: colors.faint, fontFamily: fonts.body, fontSize: 13, marginTop: 12 }}>
          MIT License
        </Text>
        <PressableBack />
      </View>
    </ScrollView>
  );
}

function PressableBack() {
  const { colors, fonts } = useTheme();
  return (
    <Text
      onPress={() => router.back()}
      style={{ color: colors.orangeText, fontFamily: fonts.medium, fontSize: 15, marginTop: 18 }}
      accessibilityRole="button"
    >
      Back to the clock
    </Text>
  );
}
