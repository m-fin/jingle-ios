import { View } from "react-native";

type MarkProps = {
  size?: number;
  sun?: string;
  pill?: string;
  glow?: string;
};

export function Mark({ size = 88, sun = "#F7931A", pill = "#F6F1E8", glow = "rgba(247,147,26,0.22)" }: MarkProps) {
  const sunSize = size * 0.46;
  const pillWidth = size * 0.78;
  const pillHeight = Math.max(6, size * 0.075);
  return (
    <View style={{ width: size, height: size, alignItems: "center", justifyContent: "center" }}>
      <View
        style={{
          position: "absolute",
          width: sunSize * 1.7,
          height: sunSize * 1.7,
          borderRadius: sunSize,
          backgroundColor: glow,
        }}
      />
      <View
        style={{
          width: sunSize,
          height: sunSize,
          borderRadius: sunSize / 2,
          backgroundColor: sun,
        }}
      />
      <View
        style={{
          position: "absolute",
          width: pillWidth,
          height: pillHeight,
          borderRadius: pillHeight,
          backgroundColor: pill,
        }}
      />
    </View>
  );
}
