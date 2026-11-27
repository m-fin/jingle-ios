import { AppState, Platform } from "react-native";
import * as Notifications from "expo-notifications";

import { clipFileExists } from "./catalogDevice";
import type { NoticeSpec } from "./schedule";
import { SOUND_LIST, MACHINE_SOUND } from "./sounds";
import type { PermissionState } from "./types";
import { resolveNotificationSound } from "./wakeClip";

export const ACTION_SNOOZE = "SNOOZE";
export const ACTION_DISMISS = "DISMISS";

let inForeground = true;
let chain: Promise<void> = Promise.resolve();
let configured = false;

function channelId(file: string): string {
  return `jingle-${file.replace(/\.wav$/, "")}`;
}

export function setNotificationsInForeground(value: boolean): void {
  inForeground = value;
}

export async function configureNotifications(): Promise<void> {
  if (configured || Platform.OS === "web") return;
  configured = true;
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: !inForeground,
      shouldShowList: true,
      shouldPlaySound: !inForeground,
      shouldSetBadge: false,
    }),
  });
  const up = {
    identifier: ACTION_DISMISS,
    buttonTitle: "I'm up",
    options: { opensAppToForeground: true, isDestructive: true },
  };
  const snooze = {
    identifier: ACTION_SNOOZE,
    buttonTitle: "Snooze",
    options: { opensAppToForeground: true },
  };
  await Notifications.setNotificationCategoryAsync("jingle-snooze", [snooze, up]);
  await Notifications.setNotificationCategoryAsync("jingle-up", [up]);
  if (Platform.OS === "android") {
    for (const file of [...SOUND_LIST.map((sound) => sound.file), MACHINE_SOUND.file]) {
      await Notifications.setNotificationChannelAsync(channelId(file), {
        name: file.replace(/\.wav$/, ""),
        importance: Notifications.AndroidImportance.MAX,
        sound: file,
        vibrationPattern: [0, 450, 180, 450],
        lockscreenVisibility: Notifications.AndroidNotificationVisibility.PUBLIC,
        bypassDnd: false,
      });
    }
  }
}

function readPayload(data: Record<string, unknown> | undefined): { alarmId?: string; purpose?: string } {
  if (!data) return {};
  return {
    alarmId: typeof data.alarmId === "string" ? data.alarmId : undefined,
    purpose: typeof data.purpose === "string" ? data.purpose : undefined,
  };
}

export function permissionFromStatus(status: Notifications.NotificationPermissionsStatus): PermissionState {
  if (status.granted) return "granted";
  if (status.canAskAgain === false && status.status === "denied") return "denied";
  return "undetermined";
}

export async function readPermission(): Promise<PermissionState> {
  if (Platform.OS === "web") {
    if (typeof Notification === "undefined") return "denied";
    if (Notification.permission === "granted") return "granted";
    if (Notification.permission === "denied") return "denied";
    return "undetermined";
  }
  try {
    return permissionFromStatus(await Notifications.getPermissionsAsync());
  } catch {
    return "undetermined";
  }
}

export async function askPermission(): Promise<PermissionState> {
  if (Platform.OS === "web") {
    if (typeof Notification === "undefined") return "denied";
    try {
      const result = await Notification.requestPermission();
      if (result === "granted") return "granted";
      return "denied";
    } catch {
      return "denied";
    }
  }
  try {
    const status = await Notifications.requestPermissionsAsync({
      ios: { allowAlert: true, allowBadge: false, allowSound: true },
    });
    return permissionFromStatus(status);
  } catch {
    return "denied";
  }
}

async function notificationFile(spec: NoticeSpec, ready: Map<string, boolean>): Promise<string> {
  const clip = spec.catalogClip ?? null;
  let clipReady = false;
  if (clip && Platform.OS === "ios") {
    const cached = ready.get(clip);
    if (cached !== undefined) clipReady = cached;
    else {
      try {
        clipReady = await clipFileExists(clip);
      } catch {
        clipReady = false;
      }
      ready.set(clip, clipReady);
    }
  }
  return resolveNotificationSound({
    sound: spec.sound,
    catalogClip: clip,
    clipReady,
    platform: Platform.OS,
  });
}

function triggerFor(spec: NoticeSpec, file: string): Notifications.NotificationTriggerInput {
  const channel = channelId(file);
  const delivery = Platform.OS === "android" && spec.purpose !== "machine" ? ("alarmClock" as const) : undefined;
  if (spec.trigger.kind === "daily") {
    return {
      type: Notifications.SchedulableTriggerInputTypes.DAILY,
      hour: spec.trigger.hour,
      minute: spec.trigger.minute,
      channelId: channel,
      ...(delivery ? { delivery } : {}),
    };
  }
  if (spec.trigger.kind === "weekly") {
    return {
      type: Notifications.SchedulableTriggerInputTypes.WEEKLY,
      weekday: spec.trigger.weekday,
      hour: spec.trigger.hour,
      minute: spec.trigger.minute,
      channelId: channel,
      ...(delivery ? { delivery } : {}),
    };
  }
  return {
    type: Notifications.SchedulableTriggerInputTypes.DATE,
    date: new Date(spec.trigger.date),
    channelId: channel,
    ...(delivery ? { delivery } : {}),
  };
}

async function applySchedule(specs: NoticeSpec[]): Promise<void> {
  if (Platform.OS === "web") return;
  await configureNotifications();
  await Notifications.cancelAllScheduledNotificationsAsync();
  const ready = new Map<string, boolean>();
  for (const spec of specs) {
    const file = await notificationFile(spec, ready);
    try {
      await Notifications.scheduleNotificationAsync({
        identifier: spec.identifier,
        content: {
          title: spec.title,
          body: spec.body,
          sound: file,
          interruptionLevel: spec.purpose === "machine" ? "active" : "timeSensitive",
          categoryIdentifier: spec.purpose === "machine" ? undefined : spec.snooze ? "jingle-snooze" : "jingle-up",
          data: { alarmId: spec.alarmId, purpose: spec.purpose },
        },
        trigger: triggerFor(spec, file),
      });
    } catch {
      // Keep scheduling the rest if one trigger is rejected.
    }
  }
}

export function reschedule(specs: NoticeSpec[]): void {
  const snapshot = specs;
  chain = chain
    .then(() => applySchedule(snapshot))
    .catch(() => {
      // A rejected schedule leaves the previous chain usable. The next edit tries again.
    });
}

export function watchNotificationEvents(handlers: {
  onResponse: (alarmId: string, purpose: string, action: string) => void;
  onReceive: (alarmId: string, purpose: string) => void;
}): () => void {
  if (Platform.OS === "web") return () => undefined;
  const seen = new Set<string>();
  const take = (alarmId: string | undefined, purpose: string | undefined, action: string, sink: (id: string, purpose: string, action: string) => void) => {
    if (!alarmId || !purpose) return;
    const key = `${alarmId}:${purpose}:${action}:${Math.floor(Date.now() / 1000)}`;
    if (seen.has(key)) return;
    seen.add(key);
    sink(alarmId, purpose, action);
  };
  const received = Notifications.addNotificationReceivedListener((notification) => {
    const payload = readPayload(notification.request.content.data);
    take(payload.alarmId, payload.purpose, "receive", (id, purpose) => handlers.onReceive(id, purpose));
  });
  const responded = Notifications.addNotificationResponseReceivedListener((response) => {
    const payload = readPayload(response.notification.request.content.data);
    take(payload.alarmId, payload.purpose, response.actionIdentifier, handlers.onResponse);
  });
  const last = Notifications.getLastNotificationResponse();
  if (last) {
    const payload = readPayload(last.notification.request.content.data);
    take(payload.alarmId, payload.purpose, last.actionIdentifier, handlers.onResponse);
  }
  const appState = AppState.addEventListener("change", (state) => {
    setNotificationsInForeground(state === "active");
  });
  return () => {
    received.remove();
    responded.remove();
    appState.remove();
  };
}
