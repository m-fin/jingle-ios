import { useFonts } from "expo-font";
import { Stack } from "expo-router";
import * as SplashScreen from "expo-splash-screen";
import { StatusBar } from "expo-status-bar";
import * as SystemUI from "expo-system-ui";
import { Fraunces_500Medium } from "@expo-google-fonts/fraunces/500Medium";
import { Fraunces_600SemiBold } from "@expo-google-fonts/fraunces/600SemiBold";
import { Outfit_400Regular } from "@expo-google-fonts/outfit/400Regular";
import { Outfit_500Medium } from "@expo-google-fonts/outfit/500Medium";
import { Outfit_600SemiBold } from "@expo-google-fonts/outfit/600SemiBold";
import { useEffect } from "react";
import { View } from "react-native";

import { AlarmsProvider } from "@/src/state/alarms";
import { ThemeBridge, useTheme } from "@/src/state/theme";

export { ErrorBoundary } from "expo-router";

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const [loaded, error] = useFonts({
    Fraunces_500Medium,
    Fraunces_600SemiBold,
    Outfit_400Regular,
    Outfit_500Medium,
    Outfit_600SemiBold,
  });

  useEffect(() => {
    if (error) throw error;
  }, [error]);

  if (!loaded) return null;

  return (
    <AlarmsProvider>
      <ThemeBridge>
        <RootNavigation />
      </ThemeBridge>
    </AlarmsProvider>
  );
}

function RootNavigation() {
  const { colors, fonts } = useTheme();

  useEffect(() => {
    void SystemUI.setBackgroundColorAsync(colors.bg);
  }, [colors.bg]);

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg, alignItems: "center" }}>
      <StatusBar style={colors.status} />
      <View style={{ flex: 1, width: "100%", maxWidth: 480, backgroundColor: colors.bg }}>
        <Stack
          screenOptions={{
            headerShadowVisible: false,
            headerTintColor: colors.text,
            headerStyle: { backgroundColor: colors.bg },
            headerTitleStyle: { fontFamily: fonts.semibold, fontSize: 17, color: colors.text },
            contentStyle: { backgroundColor: colors.bg },
            headerBackButtonDisplayMode: "minimal",
          }}
        >
          <Stack.Screen name="index" options={{ headerShown: false, title: "Jingle" }} />
          <Stack.Screen name="alarms" options={{ title: "Alarms" }} />
          <Stack.Screen name="alarm/[id]" options={{ title: "Alarm" }} />
          <Stack.Screen
            name="ringing"
            options={{
              headerShown: false,
              presentation: "fullScreenModal",
              gestureEnabled: false,
              animation: "fade",
              title: "Alarm",
            }}
          />
          <Stack.Screen name="settings" options={{ title: "Settings" }} />
        </Stack>
      </View>
    </View>
  );
}
