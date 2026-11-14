import { Platform } from "react-native";

export async function dimScreen(level: number): Promise<void> {
  if (Platform.OS === "web") return;
  try {
    const Brightness = await import("expo-brightness");
    await Brightness.setBrightnessAsync(Math.min(1, Math.max(0, level)));
  } catch {
    // Brightness control is unavailable.
  }
}

export async function restoreScreen(): Promise<void> {
  if (Platform.OS === "web") return;
  try {
    const Brightness = await import("expo-brightness");
    await Brightness.restoreSystemBrightnessAsync();
  } catch {
    // Nothing to restore.
  }
}
