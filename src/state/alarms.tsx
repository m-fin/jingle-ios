import { createContext, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { router } from "expo-router";
import * as SplashScreen from "expo-splash-screen";

import { onCatalogReady } from "@/src/lib/catalogReady";
import { playSound, stopSound } from "@/src/lib/playback";
import { MACHINE_SOUND } from "@/src/lib/sounds";
import { planNotifications } from "@/src/lib/schedule";
import { loadStore, saveStore } from "@/src/lib/storage";
import {
  atTime,
  createId,
  dateFromKey,
  expirePastOnce,
  initialOnceDate,
  isDue,
  nextOccurrence,
  normalizeAlarm,
} from "@/src/lib/time";
import {
  ACTION_DISMISS,
  ACTION_SNOOZE,
  askPermission,
  readPermission,
  reschedule,
  watchNotificationEvents,
} from "@/src/lib/notify";
import type { Alarm, PermissionState, Settings, Snooze } from "@/src/lib/types";
import { DEFAULT_SETTINGS, MAX_ALARMS, RING_WINDOW_MS } from "@/src/lib/types";

function defaultAlarm(): Alarm {
  return {
    id: createId(),
    label: "Morning",
    hour: 6,
    minute: 0,
    repeat: [1, 2, 3, 4, 5],
    onceDate: null,
    sound: "dawn",
    catalog: null,
    snoozeMinutes: 9,
    machineLeadMinutes: 0,
    enabled: true,
    createdAt: Date.now(),
  };
}

export function draftAlarm(now = new Date()): Alarm {
  const hour = (now.getHours() + 1) % 24;
  return {
    id: createId(),
    label: "Alarm",
    hour,
    minute: 0,
    repeat: [],
    onceDate: initialOnceDate(hour, 0, now),
    sound: "dawn",
    catalog: null,
    snoozeMinutes: 9,
    machineLeadMinutes: 0,
    enabled: true,
    createdAt: now.getTime(),
  };
}

function minuteStamp(date: Date): string {
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}-${date.getHours()}-${date.getMinutes()}`;
}

function dueInstant(alarm: Alarm, now: Date): Date | null {
  if (!alarm.enabled) return null;
  if (alarm.repeat.length === 0) {
    if (!alarm.onceDate) return null;
    return dateFromKey(alarm.onceDate, alarm.hour, alarm.minute);
  }
  if (!alarm.repeat.includes(now.getDay())) return null;
  return atTime(now, alarm.hour, alarm.minute);
}

type AlarmsApi = {
  ready: boolean;
  alarms: Alarm[];
  snoozes: Snooze[];
  settings: Settings;
  permission: PermissionState;
  refreshPermission: () => Promise<void>;
  requestPermission: () => Promise<void>;
  saveAlarm: (alarm: Alarm) => boolean;
  deleteAlarm: (id: string) => void;
  setEnabled: (id: string, enabled: boolean) => void;
  updateSettings: (patch: Partial<Settings>) => void;
  snoozeAlarm: (id: string) => void;
  dismissAlarm: (id: string) => void;
  claimRing: () => void;
  releaseRing: () => void;
  maxAlarms: number;
};

const AlarmsContext = createContext<AlarmsApi | null>(null);

export function AlarmsProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [alarms, setAlarms] = useState<Alarm[]>([]);
  const [snoozes, setSnoozes] = useState<Snooze[]>([]);
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS);
  const [permission, setPermission] = useState<PermissionState>("undetermined");
  const alarmsRef = useRef(alarms);
  const snoozesRef = useRef(snoozes);
  const ringingRef = useRef(false);
  const firedRef = useRef(new Set<string>());
  alarmsRef.current = alarms;
  snoozesRef.current = snoozes;

  const markFired = (key: string) => {
    if (firedRef.current.has(key)) return false;
    firedRef.current.add(key);
    return true;
  };

  const dismissAlarm = (id: string) => {
    setSnoozes((prev) => prev.filter((item) => item.alarmId !== id));
    setAlarms((prev) => prev.map((alarm) => (alarm.id === id && alarm.repeat.length === 0 ? { ...alarm, enabled: false } : alarm)));
    ringingRef.current = false;
    void stopSound();
  };

  const snoozeAlarm = (id: string) => {
    const alarm = alarmsRef.current.find((item) => item.id === id);
    if (!alarm || alarm.snoozeMinutes <= 0) {
      dismissAlarm(id);
      return;
    }
    const until = Date.now() + alarm.snoozeMinutes * 60_000;
    setSnoozes((prev) => [...prev.filter((item) => item.alarmId !== id), { alarmId: id, until }]);
    if (alarm.repeat.length === 0) {
      setAlarms((prev) => prev.map((item) => (item.id === id ? { ...item, enabled: false } : item)));
    }
    ringingRef.current = false;
    void stopSound();
  };

  const openRing = (id: string, purpose: "alarm" | "snooze") => {
    if (ringingRef.current) return;
    const alarm = alarmsRef.current.find((item) => item.id === id);
    if (!alarm) return;
    ringingRef.current = true;
    if (purpose === "snooze") {
      setSnoozes((prev) => prev.filter((item) => item.alarmId !== id));
    } else if (alarm.repeat.length === 0) {
      setAlarms((prev) => prev.map((item) => (item.id === id ? { ...item, enabled: false } : item)));
    }
    router.push(`/ringing?id=${encodeURIComponent(id)}&purpose=${purpose}`);
  };

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const stored = await loadStore();
      if (cancelled) return;
      const now = new Date();
      const nextAlarms = !stored || !stored.seeded ? [defaultAlarm()] : expirePastOnce(stored.alarms, now);
      const nextSnoozes = (stored?.snoozes ?? []).filter((item) => item.until > now.getTime() - RING_WINDOW_MS);
      setAlarms(nextAlarms);
      setSnoozes(nextSnoozes);
      setSettings(stored?.settings ?? DEFAULT_SETTINGS);
      setReady(true);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!ready) return;
    void SplashScreen.hideAsync();
  }, [ready]);

  useEffect(() => {
    if (!ready) return;
    void saveStore({ version: 1, seeded: true, alarms, snoozes, settings });
  }, [ready, alarms, snoozes, settings]);

  useEffect(() => {
    if (!ready) return;
    reschedule(planNotifications(alarms, snoozes, new Date()));
  }, [ready, alarms, snoozes]);

  useEffect(() => {
    if (!ready) return;
    return onCatalogReady(() => reschedule(planNotifications(alarmsRef.current, snoozesRef.current, new Date())));
  }, [ready]);

  useEffect(() => {
    if (!ready) return;
    void readPermission().then(setPermission);
    return watchNotificationEvents({
      onReceive: (id, purpose) => {
        const now = new Date();
        if (purpose === "machine") {
          if (markFired(`machine:${id}:${minuteStamp(now)}`) && !ringingRef.current) {
            void playSound(MACHINE_SOUND.source, { volume: 0.5 });
          }
          return;
        }
        const kind = purpose === "snooze" ? "snooze" : "alarm";
        if (!markFired(`${kind}:${id}:${minuteStamp(now)}`)) return;
        openRing(id, kind);
      },
      onResponse: (id, purpose, action) => {
        if (action === ACTION_SNOOZE) {
          snoozeAlarm(id);
          if (ringingRef.current) router.replace("/");
          return;
        }
        if (action === ACTION_DISMISS) {
          dismissAlarm(id);
          if (ringingRef.current) router.replace("/");
          return;
        }
        const kind = purpose === "snooze" ? "snooze" : "alarm";
        markFired(`${kind}:${id}:${minuteStamp(new Date())}`);
        openRing(id, kind);
      },
    });
    // Handlers read the latest alarms through refs.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready]);

  useEffect(() => {
    if (!ready) return;
    const timer = setInterval(() => {
      const now = new Date();
      for (const snooze of snoozesRef.current) {
        if (!isDue(new Date(snooze.until), now)) continue;
        if (!markFired(`snooze:${snooze.alarmId}:${minuteStamp(new Date(snooze.until))}`)) continue;
        openRing(snooze.alarmId, "snooze");
        return;
      }
      for (const alarm of alarmsRef.current) {
        const instant = dueInstant(alarm, now);
        if (instant && isDue(instant, now) && markFired(`alarm:${alarm.id}:${minuteStamp(instant)}`)) {
          openRing(alarm.id, "alarm");
          return;
        }
        if (!alarm.enabled || alarm.machineLeadMinutes <= 0 || ringingRef.current) continue;
        const wake = nextOccurrence(alarm, new Date(now.getTime() - RING_WINDOW_MS));
        if (!wake) continue;
        const machineAt = new Date(wake.getTime() - alarm.machineLeadMinutes * 60_000);
        if (!isDue(machineAt, now)) continue;
        if (markFired(`machine:${alarm.id}:${minuteStamp(machineAt)}`)) {
          void playSound(MACHINE_SOUND.source, { volume: 0.5 });
        }
      }
    }, 500);
    return () => clearInterval(timer);
  }, [ready]);

  const api = useMemo<AlarmsApi>(
    () => ({
      ready,
      alarms,
      snoozes,
      settings,
      permission,
      maxAlarms: MAX_ALARMS,
      refreshPermission: async () => setPermission(await readPermission()),
      requestPermission: async () => {
        const next = await askPermission();
        setPermission(next);
        if (next === "granted") reschedule(planNotifications(alarmsRef.current, snoozesRef.current, new Date()));
      },
      saveAlarm: (alarm) => {
        const normalized = normalizeAlarm(alarm, new Date());
        const exists = alarms.some((item) => item.id === normalized.id);
        if (!exists && alarms.length >= MAX_ALARMS) return false;
        setAlarms((prev) => {
          const has = prev.some((item) => item.id === normalized.id);
          if (!has && prev.length >= MAX_ALARMS) return prev;
          return has ? prev.map((item) => (item.id === normalized.id ? normalized : item)) : [...prev, normalized];
        });
        return true;
      },
      deleteAlarm: (id) => {
        setAlarms((prev) => prev.filter((item) => item.id !== id));
        setSnoozes((prev) => prev.filter((item) => item.alarmId !== id));
        void stopSound();
      },
      setEnabled: (id, enabled) => {
        setAlarms((prev) =>
          prev.map((item) => {
            if (item.id !== id) return item;
            if (!enabled) return { ...item, enabled: false };
            return normalizeAlarm({ ...item, enabled: true }, new Date());
          }),
        );
      },
      updateSettings: (patch) => setSettings((prev) => ({ ...prev, ...patch })),
      snoozeAlarm,
      dismissAlarm,
      claimRing: () => {
        ringingRef.current = true;
      },
      releaseRing: () => {
        ringingRef.current = false;
      },
    }),
    [alarms, permission, ready, settings, snoozes],
  );

  return <AlarmsContext.Provider value={api}>{children}</AlarmsContext.Provider>;
}

export function useAlarms(): AlarmsApi {
  const value = useContext(AlarmsContext);
  if (!value) throw new Error("useAlarms must be used inside AlarmsProvider");
  return value;
}
