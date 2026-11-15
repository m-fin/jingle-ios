import { useRef } from "react";
import { Platform, Pressable, Text, View, type StyleProp, type ViewStyle } from "react-native";

import { haptic } from "@/src/lib/haptics";
import { useTheme } from "@/src/state/theme";

export const pressCursor: ViewStyle = Platform.OS === "web" ? ({ cursor: "pointer" } as ViewStyle) : {};

type PillProps = {
  label: string;
  onPress: () => void;
  tone?: "solid" | "quiet" | "ghost";
  testID?: string;
  accessibilityLabel?: string;
};

export function Pill({ label, onPress, tone = "solid", testID, accessibilityLabel }: PillProps) {
  const { colors, fonts } = useTheme();
  const backgroundColor = tone === "solid" ? colors.orange : tone === "quiet" ? colors.card : "transparent";
  const color = tone === "solid" ? colors.onOrange : tone === "ghost" ? colors.orangeText : colors.text;
  const borderColor = tone === "solid" ? colors.orange : colors.cardBorder;
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      onPress={() => {
        void haptic("light");
        onPress();
      }}
      style={({ pressed }) => [
        pressCursor,
        {
          minHeight: 56,
          borderRadius: 28,
          alignItems: "center",
          justifyContent: "center",
          paddingHorizontal: 18,
          backgroundColor,
          borderWidth: 1,
          borderColor,
          opacity: pressed ? 0.82 : 1,
        },
      ]}
    >
      <Text style={{ color, fontFamily: fonts.semibold, fontSize: 17 }}>{label}</Text>
    </Pressable>
  );
}

type SwitchProps = {
  value: boolean;
  onValueChange: (value: boolean) => void;
  label: string;
};

export function Switch({ value, onValueChange, label }: SwitchProps) {
  const { colors } = useTheme();
  return (
    <Pressable
      accessibilityRole="switch"
      accessibilityLabel={label}
      accessibilityState={{ checked: value }}
      hitSlop={10}
      onPress={() => {
        void haptic(value ? "light" : "medium");
        onValueChange(!value);
      }}
      style={[
        pressCursor,
        {
          width: 52,
          height: 32,
          borderRadius: 16,
          padding: 3,
          backgroundColor: value ? colors.orange : colors.switchOff,
          justifyContent: "center",
        },
      ]}
    >
      <View
        style={{
          width: 26,
          height: 26,
          borderRadius: 13,
          backgroundColor: "#FFFBF7",
          transform: [{ translateX: value ? 20 : 0 }],
        }}
      />
    </Pressable>
  );
}

type SegmentProps<T extends string | number> = {
  options: { label: string; value: T }[];
  value: T;
  onChange: (value: T) => void;
};

export function Segment<T extends string | number>({ options, value, onChange }: SegmentProps<T>) {
  const { colors, fonts } = useTheme();
  return (
    <View
      style={{
        flexDirection: "row",
        backgroundColor: colors.card,
        borderRadius: 16,
        padding: 4,
        borderWidth: 1,
        borderColor: colors.cardBorder,
        gap: 4,
      }}
    >
      {options.map((option) => {
        const selected = option.value === value;
        return (
          <Pressable
            key={String(option.value)}
            accessibilityRole="button"
            accessibilityState={{ selected }}
            onPress={() => {
              void haptic("select");
              onChange(option.value);
            }}
            style={[
              pressCursor,
              {
                flex: 1,
                minHeight: 40,
                borderRadius: 12,
                alignItems: "center",
                justifyContent: "center",
                paddingHorizontal: 6,
                backgroundColor: selected ? colors.orange : "transparent",
              },
            ]}
          >
            <Text style={{ color: selected ? colors.onOrange : colors.text, fontFamily: fonts.medium, fontSize: 14 }}>{option.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

type StepButtonProps = {
  glyph: string;
  accessibilityLabel: string;
  onStep: () => void;
};

export function StepButton({ glyph, accessibilityLabel, onStep }: StepButtonProps) {
  const { colors, fonts } = useTheme();
  const delay = useRef<ReturnType<typeof setTimeout> | null>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  const stepped = useRef(false);
  const stop = () => {
    if (delay.current) clearTimeout(delay.current);
    if (timer.current) clearInterval(timer.current);
    delay.current = null;
    timer.current = null;
  };
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      onPressIn={() => {
        stepped.current = true;
        void haptic("select");
        onStep();
        delay.current = setTimeout(() => {
          timer.current = setInterval(() => {
            void haptic("select");
            onStep();
          }, 110);
        }, 340);
      }}
      onPress={() => {
        if (stepped.current) {
          stepped.current = false;
          return;
        }
        void haptic("select");
        onStep();
      }}
      onPressOut={stop}
      style={({ pressed }) => [
        pressCursor,
        {
          width: 64,
          height: 64,
          borderRadius: 32,
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: pressed ? colors.orange : colors.card,
          borderWidth: 1,
          borderColor: pressed ? colors.orange : colors.cardBorder,
        },
      ]}
    >
      <Text style={{ color: colors.text, fontFamily: fonts.semibold, fontSize: 30, lineHeight: 34 }}>{glyph}</Text>
    </Pressable>
  );
}

export function rowPressable(extra?: StyleProp<ViewStyle>): StyleProp<ViewStyle> {
  return [pressCursor, extra];
}
