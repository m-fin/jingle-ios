import { router, Stack } from "expo-router";
import { Pressable, ScrollView, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { Pill, pressCursor, Switch } from "@/components/ui";
import { SOUNDS } from "@/src/lib/sounds";
import { formatClock, repeatLabel, sortAlarms } from "@/src/lib/time";
import { useAlarms } from "@/src/state/alarms";
import { useTheme } from "@/src/state/theme";

export default function AlarmsScreen() {
  const insets = useSafeAreaInsets();
  const { colors, fonts } = useTheme();
  const { alarms, setEnabled, maxAlarms } = useAlarms();
  const ordered = sortAlarms(alarms);
  const canAdd = alarms.length < maxAlarms;

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <Stack.Screen
        options={{
          title: "Alarms",
          headerRight: () => (
            <Pressable
              testID="add-alarm"
              accessibilityRole="button"
              accessibilityLabel="Add alarm"
              disabled={!canAdd}
              onPress={() => router.push("/alarm/new")}
              hitSlop={8}
              style={[pressCursor, { opacity: canAdd ? 1 : 0.35, paddingHorizontal: 4 }]}
            >
              <Text style={{ color: colors.orangeText, fontFamily: fonts.semibold, fontSize: 16 }}>Add</Text>
            </Pressable>
          ),
        }}
      />
      <ScrollView contentContainerStyle={{ paddingHorizontal: 20, paddingTop: 8, paddingBottom: Math.max(insets.bottom, 28) }}>
        <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 15, lineHeight: 21, marginBottom: 16 }}>
          One wake time is enough for most mornings. Add another only when the day asks for it.
        </Text>
        {ordered.length === 0 ? (
          <View style={{ alignItems: "flex-start", paddingTop: 28, gap: 16 }}>
            <Text style={{ color: colors.text, fontFamily: fonts.clock, fontSize: 36 }}>No alarms</Text>
            <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 16 }}>The morning is open.</Text>
            <Pill label="Add an alarm" onPress={() => router.push("/alarm/new")} />
          </View>
        ) : (
          <View style={{ gap: 12 }}>
            {ordered.map((alarm) => (
              <Pressable
                key={alarm.id}
                testID={`alarm-row-${alarm.id}`}
                accessibilityRole="button"
                accessibilityLabel={`${alarm.label}, ${formatClock(alarm.hour, alarm.minute)}, ${repeatLabel(alarm.repeat)}`}
                onPress={() => router.push(`/alarm/${alarm.id}`)}
                style={[
                  pressCursor,
                  {
                    backgroundColor: colors.card,
                    borderRadius: 24,
                    borderWidth: 1,
                    borderColor: colors.cardBorder,
                    paddingHorizontal: 18,
                    paddingVertical: 16,
                    flexDirection: "row",
                    alignItems: "center",
                    gap: 12,
                  },
                ]}
              >
                <View style={{ flex: 1, opacity: alarm.enabled ? 1 : 0.45 }}>
                  <Text style={{ color: colors.text, fontFamily: fonts.clock, fontSize: 36, fontVariant: ["tabular-nums"] }}>
                    {formatClock(alarm.hour, alarm.minute)}
                  </Text>
                  <Text style={{ color: colors.muted, fontFamily: fonts.body, fontSize: 15, marginTop: 2 }}>
                    {alarm.label}  ·  {repeatLabel(alarm.repeat)}  ·  {SOUNDS[alarm.sound].name}
                  </Text>
                </View>
                <Switch label={`Toggle ${alarm.label}`} value={alarm.enabled} onValueChange={(enabled) => setEnabled(alarm.id, enabled)} />
              </Pressable>
            ))}
          </View>
        )}
        {!canAdd ? (
          <Text style={{ color: colors.faint, fontFamily: fonts.body, fontSize: 13, marginTop: 16 }}>
            Eight alarms is the limit so every one can still be scheduled on iPhone.
          </Text>
        ) : null}
      </ScrollView>
    </View>
  );
}
