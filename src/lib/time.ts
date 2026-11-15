import type { Alarm, Snooze } from "./types";

export const WEEKDAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"] as const;
export const WEEKDAY_LETTERS = ["S", "M", "T", "W", "T", "F", "S"] as const;

const WEEKDAYS = [1, 2, 3, 4, 5];
const WEEKENDS = [0, 6];
const EVERY_DAY = [0, 1, 2, 3, 4, 5, 6];

export function createId(): string {
  const cryptoObj = globalThis.crypto;
  if (cryptoObj && typeof cryptoObj.randomUUID === "function") {
    return cryptoObj.randomUUID();
  }
  return `jingle-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

export function dateKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function atTime(day: Date, hour: number, minute: number): Date {
  const next = new Date(day);
  next.setHours(hour, minute, 0, 0);
  return next;
}

export function dateFromKey(key: string, hour: number, minute: number): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(key);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(year, month - 1, day, hour, minute, 0, 0);
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) return null;
  return date;
}

export function initialOnceDate(hour: number, minute: number, now: Date): string {
  const today = atTime(now, hour, minute);
  if (today.getTime() > now.getTime()) return dateKey(today);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  return dateKey(tomorrow);
}

export type ScheduleAlarm = Pick<Alarm, "hour" | "minute" | "repeat" | "enabled" | "onceDate">;

export function nextOccurrence(alarm: ScheduleAlarm, now: Date): Date | null {
  if (!alarm.enabled) return null;
  if (alarm.repeat.length === 0) {
    if (!alarm.onceDate) return null;
    const when = dateFromKey(alarm.onceDate, alarm.hour, alarm.minute);
    if (!when || when.getTime() <= now.getTime()) return null;
    return when;
  }
  for (let offset = 0; offset < 8; offset += 1) {
    const day = new Date(now);
    day.setDate(now.getDate() + offset);
    day.setHours(alarm.hour, alarm.minute, 0, 0);
    if (!alarm.repeat.includes(day.getDay())) continue;
    if (day.getTime() > now.getTime()) return day;
  }
  return null;
}

export function isDue(target: Date, now: Date, windowMs = 50_000): boolean {
  const delta = now.getTime() - target.getTime();
  return delta >= 0 && delta < windowMs;
}

export function machineWeekly(alarm: Pick<Alarm, "hour" | "minute" | "machineLeadMinutes" | "repeat">): {
  hour: number;
  minute: number;
  days: number[];
} {
  const total = alarm.hour * 60 + alarm.minute - alarm.machineLeadMinutes;
  const shift = total < 0 ? -1 : total >= 24 * 60 ? 1 : 0;
  const minutes = ((total % (24 * 60)) + 24 * 60) % (24 * 60);
  const days = [...new Set(alarm.repeat.map((day) => (day + shift + 7) % 7))].sort((a, b) => a - b);
  return { hour: Math.floor(minutes / 60), minute: minutes % 60, days };
}

export function to12(hour: number): { hour12: number; period: "AM" | "PM" } {
  const period = hour >= 12 ? "PM" : "AM";
  const hour12 = hour % 12 === 0 ? 12 : hour % 12;
  return { hour12, period };
}

export function to24(hour12: number, period: "AM" | "PM"): number {
  if (period === "AM") return hour12 === 12 ? 0 : hour12;
  return hour12 === 12 ? 12 : hour12 + 12;
}

export function formatClock(hour: number, minute: number): string {
  const { hour12, period } = to12(hour);
  return `${String(hour12).padStart(2, "0")}:${String(minute).padStart(2, "0")} ${period}`;
}

export function clockParts(date: Date): { hour: string; minute: string; second: string; period: "AM" | "PM" } {
  const { hour12, period } = to12(date.getHours());
  return {
    hour: String(hour12).padStart(2, "0"),
    minute: String(date.getMinutes()).padStart(2, "0"),
    second: String(date.getSeconds()).padStart(2, "0"),
    period,
  };
}

export function dateLines(date: Date): { weekday: string; day: string } {
  return {
    weekday: date.toLocaleDateString("en-US", { weekday: "long" }).toUpperCase(),
    day: date.toLocaleDateString("en-US", { month: "long", day: "numeric" }),
  };
}

export function sameDays(left: number[], right: number[]): boolean {
  if (left.length !== right.length) return false;
  const a = [...left].sort((x, y) => x - y);
  const b = [...right].sort((x, y) => x - y);
  return a.every((value, index) => value === b[index]);
}

export function repeatLabel(days: number[]): string {
  if (days.length === 0) return "Once";
  if (sameDays(days, EVERY_DAY)) return "Every day";
  if (sameDays(days, WEEKDAYS)) return "Weekdays";
  if (sameDays(days, WEEKENDS)) return "Weekends";
  return [...days]
    .sort((a, b) => a - b)
    .map((day) => WEEKDAY_NAMES[day]?.slice(0, 3) ?? "")
    .join(" ");
}

export function relativeRing(when: Date, now: Date): string {
  const minutes = Math.max(0, Math.round((when.getTime() - now.getTime()) / 60_000));
  if (minutes < 1) return "Rings now";
  if (minutes < 60) return `Rings in ${minutes} ${minutes === 1 ? "minute" : "minutes"}`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours < 18) {
    const hourLabel = `${hours} ${hours === 1 ? "hour" : "hours"}`;
    return rest === 0 ? `Rings in ${hourLabel}` : `Rings in ${hourLabel} ${rest} min`;
  }
  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);
  if (dateKey(when) === dateKey(tomorrow)) return "Rings tomorrow";
  if (dateKey(when) === dateKey(now)) return `Rings at ${formatClock(when.getHours(), when.getMinutes())}`;
  return `Rings ${WEEKDAY_NAMES[when.getDay()]}`;
}

export type Upcoming = {
  alarm: Alarm;
  when: Date;
  kind: "alarm" | "snooze";
};

export function nextUp(alarms: Alarm[], snoozes: Snooze[], now: Date): Upcoming | null {
  let best: Upcoming | null = null;
  for (const alarm of alarms) {
    const when = nextOccurrence(alarm, now);
    if (!when) continue;
    if (!best || when.getTime() < best.when.getTime()) best = { alarm, when, kind: "alarm" };
  }
  for (const snooze of snoozes) {
    if (snooze.until <= now.getTime()) continue;
    const alarm = alarms.find((item) => item.id === snooze.alarmId);
    if (!alarm) continue;
    const when = new Date(snooze.until);
    if (!best || when.getTime() < best.when.getTime()) best = { alarm, when, kind: "snooze" };
  }
  return best;
}

export function sortAlarms(alarms: Alarm[]): Alarm[] {
  return [...alarms].sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute) || a.label.localeCompare(b.label));
}

export function normalizeAlarm(alarm: Alarm, now: Date): Alarm {
  const repeat = [...new Set(alarm.repeat.filter((day) => day >= 0 && day <= 6))].sort((a, b) => a - b);
  const label = alarm.label.trim().slice(0, 40) || "Alarm";
  if (repeat.length > 0) {
    return { ...alarm, label, repeat, onceDate: null };
  }
  return { ...alarm, label, repeat: [], onceDate: initialOnceDate(alarm.hour, alarm.minute, now) };
}

export function expirePastOnce(alarms: Alarm[], now: Date): Alarm[] {
  return alarms.map((alarm) => {
    if (!alarm.enabled || alarm.repeat.length > 0) return alarm;
    if (nextOccurrence(alarm, now)) return alarm;
    return { ...alarm, enabled: false };
  });
}

export const REPEAT_PRESETS: { label: string; days: number[] }[] = [
  { label: "Once", days: [] },
  { label: "Weekdays", days: WEEKDAYS },
  { label: "Weekends", days: WEEKENDS },
  { label: "Every day", days: EVERY_DAY },
];
