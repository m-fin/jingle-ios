export type SoundId = "dawn" | "bell" | "pulse" | "chime";

/** A track chosen from the Matthew Finley catalog. The bundled `sound` remains the fallback. */
export type CatalogTone = {
  trackId: string;
  title: string;
  collection: string;
};

export type Alarm = {
  id: string;
  label: string;
  hour: number;
  minute: number;
  /** JavaScript weekday, Sunday = 0. Empty means the alarm rings once. */
  repeat: number[];
  /** Local calendar day (YYYY-MM-DD) for a one-time alarm. */
  onceDate: string | null;
  sound: SoundId;
  /** Set when the wake tone is a downloaded Matthew Finley catalog track. */
  catalogTone?: CatalogTone | null;
  /** Minutes. Zero turns snooze off for this alarm. */
  snoozeMinutes: 0 | 5 | 9 | 15;
  /** Minutes of gentle sound before the alarm. Zero turns machine mode off. */
  machineLeadMinutes: 0 | 10 | 20;
  enabled: boolean;
  createdAt: number;
};

export type Snooze = {
  alarmId: string;
  until: number;
};

export type ThemeChoice = "night" | "day" | "system";

export type Settings = {
  theme: ThemeChoice;
  autoBlank: boolean;
  bedsideDim: boolean;
};

export type Store = {
  version: 1;
  seeded: boolean;
  alarms: Alarm[];
  snoozes: Snooze[];
  settings: Settings;
};

export type PermissionState = "granted" | "denied" | "undetermined";

export const MAX_ALARMS = 8;
export const BLANK_AFTER_MS = 45_000;
export const NOTIFICATION_BUDGET = 56;
export const RING_WINDOW_MS = 50_000;

export const DEFAULT_SETTINGS: Settings = {
  theme: "night",
  autoBlank: true,
  bedsideDim: true,
};
