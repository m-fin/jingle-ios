import { Linking, ScrollView, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { SOURCE_REPOSITORY } from "@/src/lib/release";
import { useTheme } from "@/src/state/theme";

const ISSUES = `${SOURCE_REPOSITORY}/issues`;

export default function PrivacyScreen() {
  const insets = useSafeAreaInsets();
  const { colors, fonts } = useTheme();
  const body = { color: colors.muted, fontFamily: fonts.body, fontSize: 16, lineHeight: 23 };
  const heading = {
    color: colors.text,
    fontFamily: fonts.semibold,
    fontSize: 18,
    marginTop: 22,
  };

  return (
    <ScrollView
      testID="privacy-screen"
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ paddingHorizontal: 22, paddingTop: 8, paddingBottom: Math.max(insets.bottom, 32) }}
    >
      <Text style={{ color: colors.faint, fontFamily: fonts.medium, fontSize: 13 }}>Effective 15 November 2026</Text>
      <Text style={{ ...body, marginTop: 12 }}>
        Jingle is a bedside alarm clock. What you set stays on the iPhone running the app.
      </Text>

      <Text style={heading}>On this phone</Text>
      <Text style={{ ...body, marginTop: 8 }}>
        Alarms, snooze times, and appearance are saved on the device. Jingle does not send that store to a server. The clock uses the iPhone’s own
        time and does not request location. While the clock is open it can dim the screen, then restore the brightness you had before.
      </Text>

      <Text style={heading}>Notifications</Text>
      <Text style={{ ...body, marginTop: 8 }}>
        Alarms after the screen locks are local notifications. Remote push is off, and Jingle does not upload a push token. A locked phone plays the
        tone through iOS. An open Jingle plays it in the app.
      </Text>

      <Text style={heading}>Not collected</Text>
      <Text style={{ ...body, marginTop: 8 }}>
        No account, no analytics, and no advertising. Jingle does not sell or share personal information. It does not collect your name, email,
        contacts, photos, health data, or location. Wake tones are original audio shipped inside the app.
      </Text>

      <View style={{ marginTop: 22 }}>
        <Text style={body}>
          Questions about this policy can go to the project issues page.
        </Text>
        <Text
          accessibilityRole="link"
          onPress={() => void Linking.openURL(ISSUES)}
          style={{ color: colors.orangeText, fontFamily: fonts.medium, fontSize: 16, marginTop: 10 }}
        >
          {ISSUES}
        </Text>
      </View>
    </ScrollView>
  );
}
