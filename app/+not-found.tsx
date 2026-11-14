import { Link, Stack } from "expo-router";
import { Text, View } from "react-native";

import { useTheme } from "@/src/state/theme";

export default function NotFoundScreen() {
  const { colors, fonts } = useTheme();
  return (
    <>
      <Stack.Screen options={{ title: "Jingle" }} />
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: colors.bg, padding: 24 }}>
        <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 22 }}>That screen is not here.</Text>
        <Link href="/" style={{ marginTop: 18 }}>
          <Text style={{ color: colors.orangeText, fontFamily: fonts.medium, fontSize: 16 }}>Back to the clock</Text>
        </Link>
      </View>
    </>
  );
}
