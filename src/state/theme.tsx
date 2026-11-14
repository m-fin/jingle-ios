import { createContext, useContext, useMemo, type ReactNode } from "react";
import { useColorScheme } from "react-native";

import { useAlarms } from "@/src/state/alarms";
import type { ThemeChoice } from "@/src/lib/types";

export type Palette = {
  bg: string;
  card: string;
  cardBorder: string;
  text: string;
  muted: string;
  faint: string;
  orange: string;
  orangeText: string;
  ivory: string;
  onOrange: string;
  danger: string;
  switchOff: string;
  glow: string;
  status: "light" | "dark";
};

const night: Palette = {
  bg: "#070708",
  card: "#161618",
  cardBorder: "rgba(255,255,255,0.06)",
  text: "#F6F1E8",
  muted: "#9A948A",
  faint: "#6A645C",
  orange: "#F7931A",
  orangeText: "#FFB15A",
  ivory: "#F6F1E8",
  onOrange: "#1A1208",
  danger: "#E15A4A",
  switchOff: "#2C2C30",
  glow: "rgba(247,147,26,0.18)",
  status: "light",
};

const day: Palette = {
  bg: "#F3EEE6",
  card: "#FFFBF6",
  cardBorder: "rgba(40,28,16,0.08)",
  text: "#1C140E",
  muted: "#6F655B",
  faint: "#A3988C",
  orange: "#E07A12",
  orangeText: "#B45309",
  ivory: "#1C140E",
  onOrange: "#1A1208",
  danger: "#C24130",
  switchOff: "#E4DDD2",
  glow: "rgba(224,122,18,0.16)",
  status: "dark",
};

export const fonts = {
  clock: "Fraunces_500Medium",
  clockBold: "Fraunces_600SemiBold",
  body: "Outfit_400Regular",
  medium: "Outfit_500Medium",
  semibold: "Outfit_600SemiBold",
};

type ThemeValue = {
  mode: "night" | "day";
  choice: ThemeChoice;
  colors: Palette;
  fonts: typeof fonts;
};

const ThemeContext = createContext<ThemeValue | null>(null);

export function ThemeBridge({ children }: { children: ReactNode }) {
  const { settings, ready } = useAlarms();
  const system = useColorScheme();
  const mode = settings.theme === "system" ? (system === "light" ? "day" : "night") : settings.theme === "day" ? "day" : "night";
  const value = useMemo<ThemeValue>(
    () => ({
      mode,
      choice: settings.theme,
      colors: mode === "day" ? day : night,
      fonts,
    }),
    [mode, settings.theme],
  );
  if (!ready) return null;
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeValue {
  const value = useContext(ThemeContext);
  if (!value) throw new Error("useTheme must be used inside ThemeBridge");
  return value;
}
