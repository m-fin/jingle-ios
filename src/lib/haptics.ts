import { Platform } from "react-native";
import * as Haptics from "expo-haptics";

export type HapticKind = "select" | "light" | "medium" | "heavy" | "success" | "warning";

export async function haptic(kind: HapticKind): Promise<void> {
  if (Platform.OS === "web") {
    const activation = typeof navigator !== "undefined" ? navigator.userActivation : undefined;
    if (activation && !activation.hasBeenActive) return;
    if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
      const pattern = kind === "heavy" ? [24, 40, 24] : kind === "warning" ? [16, 30, 16] : 12;
      try {
        navigator.vibrate(pattern);
      } catch {
        // The browser blocked vibration before the first tap.
      }
    }
    return;
  }
  try {
    if (kind === "select") {
      await Haptics.selectionAsync();
      return;
    }
    if (kind === "success") {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      return;
    }
    if (kind === "warning") {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
      return;
    }
    const style =
      kind === "heavy"
        ? Haptics.ImpactFeedbackStyle.Heavy
        : kind === "medium"
          ? Haptics.ImpactFeedbackStyle.Medium
          : Haptics.ImpactFeedbackStyle.Light;
    await Haptics.impactAsync(style);
  } catch {
    // Haptics are unavailable on this device.
  }
}
