import { sanitizeCatalogTone } from "./tone";
import type { Alarm, Settings, Snooze, SoundId, Store, ThemeChoice } from "./types";
import { DEFAULT_SETTINGS } from "./types";

const KEY = "jingle.v1";
const SOUNDS = new Set<SoundId>(["dawn", "bell", "pulse", "chime"]);
const SNOOZE = new Set([0, 5, 9, 15]);
const MACHINE = new Set([0, 10, 20]);
const THEMES = new Set<ThemeChoice>(["night", "day", "system"]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function sanitizeAlarm(value: unknown): Alarm | null {
  if (!isRecord(value)) return null;
  if (typeof value.id !== "string" || value.id.length === 0 || value.id.length > 80) return null;
  if (typeof value.hour !== "number" || value.hour < 0 || value.hour > 23) return null;
  if (typeof value.minute !== "number" || value.minute < 0 || value.minute > 59) return null;
  const sound = SOUNDS.has(value.sound as SoundId) ? (value.sound as SoundId) : "dawn";
  const catalog = sanitizeCatalogTone(value.catalog);
  const snoozeMinutes = SNOOZE.has(value.snoozeMinutes as number) ? (value.snoozeMinutes as Alarm["snoozeMinutes"]) : 9;
  const machineLeadMinutes = MACHINE.has(value.machineLeadMinutes as number)
    ? (value.machineLeadMinutes as Alarm["machineLeadMinutes"])
    : 0;
  const repeat = Array.isArray(value.repeat)
    ? [...new Set(value.repeat.filter((day): day is number => typeof day === "number" && Number.isInteger(day) && day >= 0 && day <= 6))].sort(
        (a, b) => a - b,
      )
    : [];
  const onceDate = typeof value.onceDate === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value.onceDate) ? value.onceDate : null;
  const label = typeof value.label === "string" && value.label.trim() ? value.label.trim().slice(0, 40) : "Alarm";
  return {
    id: value.id,
    label,
    hour: Math.floor(value.hour),
    minute: Math.floor(value.minute),
    repeat,
    onceDate: repeat.length > 0 ? null : onceDate,
    sound,
    catalog,
    snoozeMinutes,
    machineLeadMinutes,
    enabled: value.enabled !== false,
    createdAt: typeof value.createdAt === "number" ? value.createdAt : Date.now(),
  };
}

function sanitizeSettings(value: unknown): Settings {
  if (!isRecord(value)) return { ...DEFAULT_SETTINGS };
  return {
    theme: THEMES.has(value.theme as ThemeChoice) ? (value.theme as ThemeChoice) : "night",
    autoBlank: value.autoBlank !== false,
    bedsideDim: value.bedsideDim !== false,
  };
}

export function sanitizeStore(value: unknown): Store | null {
  if (!isRecord(value) || value.version !== 1) return null;
  const alarms = Array.isArray(value.alarms) ? value.alarms.map(sanitizeAlarm).filter((alarm): alarm is Alarm => alarm !== null) : [];
  const ids = new Set(alarms.map((alarm) => alarm.id));
  const snoozes = Array.isArray(value.snoozes)
    ? value.snoozes
        .filter(isRecord)
        .map((item) => ({
          alarmId: typeof item.alarmId === "string" ? item.alarmId : "",
          until: typeof item.until === "number" ? item.until : 0,
        }))
        .filter((item): item is Snooze => item.alarmId.length > 0 && ids.has(item.alarmId) && item.until > 0)
    : [];
  return {
    version: 1,
    seeded: value.seeded === true,
    alarms: alarms.slice(0, 8),
    snoozes,
    settings: sanitizeSettings(value.settings),
  };
}

async function deviceStorage(): Promise<{ getItem(key: string): Promise<string | null>; setItem(key: string, value: string): Promise<void> }> {
  const module = await import("@react-native-async-storage/async-storage");
  return module.default;
}

export async function loadStore(): Promise<Store | null> {
  try {
    const raw = await (await deviceStorage()).getItem(KEY);
    if (!raw) return null;
    return sanitizeStore(JSON.parse(raw) as unknown);
  } catch {
    return null;
  }
}

export async function saveStore(store: Store): Promise<void> {
  await (await deviceStorage()).setItem(KEY, JSON.stringify(store));
}
