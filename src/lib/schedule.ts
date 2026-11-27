import { catalogWakeFilename } from "./tone";
import type { Alarm, Snooze, SoundId } from "./types";
import { NOTIFICATION_BUDGET } from "./types";
import { machineWeekly, nextOccurrence } from "./time";

export type NoticeSound = SoundId | "machine";
export type NoticePurpose = "alarm" | "machine" | "snooze";

export type NoticeTrigger =
  | { kind: "daily"; hour: number; minute: number }
  | { kind: "weekly"; weekday: number; hour: number; minute: number }
  | { kind: "date"; date: number };

export type NoticeSpec = {
  identifier: string;
  title: string;
  body: string;
  sound: NoticeSound;
  alarmId: string;
  purpose: NoticePurpose;
  snooze: boolean;
  /** CAF filename for a downloaded catalog track. Null uses the bundled sound. */
  catalogFile: string | null;
  trigger: NoticeTrigger;
};

function catalogSoundFile(alarm: Alarm): string | null {
  if (!alarm.catalog) return null;
  return catalogWakeFilename(alarm.catalog.trackId);
}

function alarmNotices(alarm: Alarm, now: Date): NoticeSpec[] {
  const title = alarm.label || "Jingle";
  const snooze = alarm.snoozeMinutes > 0;
  const base = {
    title,
    body: "Time to get up.",
    sound: alarm.sound,
    alarmId: alarm.id,
    purpose: "alarm" as const,
    snooze,
    catalogFile: catalogSoundFile(alarm),
  };
  if (alarm.repeat.length === 0) {
    const when = nextOccurrence(alarm, now);
    if (!when) return [];
    return [{ ...base, identifier: `jingle-${alarm.id}-once`, trigger: { kind: "date", date: when.getTime() } }];
  }
  if (alarm.repeat.length === 7) {
    return [
      {
        ...base,
        identifier: `jingle-${alarm.id}-daily`,
        trigger: { kind: "daily", hour: alarm.hour, minute: alarm.minute },
      },
    ];
  }
  return [...alarm.repeat].sort((a, b) => a - b).map((day) => ({
    ...base,
    identifier: `jingle-${alarm.id}-d${day}`,
    trigger: { kind: "weekly" as const, weekday: day + 1, hour: alarm.hour, minute: alarm.minute },
  }));
}

function machineNotices(alarm: Alarm, now: Date): NoticeSpec[] {
  if (alarm.machineLeadMinutes <= 0) return [];
  const title = "Jingle";
  const body = `Soft start before ${alarm.label || "your alarm"}.`;
  const shared = {
    title,
    body,
    sound: "machine" as const,
    alarmId: alarm.id,
    purpose: "machine" as const,
    snooze: false,
    catalogFile: null,
  };
  if (alarm.repeat.length === 0) {
    const when = nextOccurrence(alarm, now);
    if (!when) return [];
    const at = when.getTime() - alarm.machineLeadMinutes * 60_000;
    if (at <= now.getTime() + 1000) return [];
    return [{ ...shared, identifier: `jingle-${alarm.id}-machine`, trigger: { kind: "date", date: at } }];
  }
  const slot = machineWeekly(alarm);
  if (slot.days.length === 7) {
    return [
      {
        ...shared,
        identifier: `jingle-${alarm.id}-machine-daily`,
        trigger: { kind: "daily", hour: slot.hour, minute: slot.minute },
      },
    ];
  }
  return slot.days.map((day) => ({
    ...shared,
    identifier: `jingle-${alarm.id}-machine-d${day}`,
    trigger: { kind: "weekly" as const, weekday: day + 1, hour: slot.hour, minute: slot.minute },
  }));
}

export function planNotifications(alarms: Alarm[], snoozes: Snooze[], now: Date): NoticeSpec[] {
  const primary: NoticeSpec[] = [];
  const gentle: NoticeSpec[] = [];
  for (const alarm of alarms) {
    if (!alarm.enabled) continue;
    primary.push(...alarmNotices(alarm, now));
    gentle.push(...machineNotices(alarm, now));
  }
  for (const snooze of snoozes) {
    if (snooze.until <= now.getTime() + 1000) continue;
    const alarm = alarms.find((item) => item.id === snooze.alarmId);
    if (!alarm) continue;
    primary.push({
      identifier: `jingle-snooze-${alarm.id}`,
      title: alarm.label || "Jingle",
      body: "Still time to get up.",
      sound: alarm.sound,
      alarmId: alarm.id,
      purpose: "snooze",
      snooze: alarm.snoozeMinutes > 0,
      catalogFile: catalogSoundFile(alarm),
      trigger: { kind: "date", date: snooze.until },
    });
  }
  const room = Math.max(0, NOTIFICATION_BUDGET - primary.length);
  return [...primary, ...gentle.slice(0, room)].slice(0, NOTIFICATION_BUDGET);
}
