import assert from "node:assert/strict";
import { test } from "node:test";

import { planNotifications } from "./schedule";
import type { Alarm } from "./types";
import {
  expirePastOnce,
  formatClock,
  initialOnceDate,
  isDue,
  machineWeekly,
  nextOccurrence,
  normalizeAlarm,
  relativeRing,
  repeatLabel,
  to12,
  to24,
} from "./time";

function alarm(overrides: Partial<Alarm> = {}): Alarm {
  return {
    id: "morning",
    label: "Morning",
    hour: 6,
    minute: 0,
    repeat: [1, 2, 3, 4, 5],
    onceDate: null,
    sound: "dawn",
    snoozeMinutes: 9,
    machineLeadMinutes: 0,
    enabled: true,
    createdAt: 0,
    ...overrides,
  };
}

test("converts 24-hour times to a 12-hour clock", () => {
  assert.deepEqual(to12(0), { hour12: 12, period: "AM" });
  assert.deepEqual(to12(6), { hour12: 6, period: "AM" });
  assert.deepEqual(to12(12), { hour12: 12, period: "PM" });
  assert.deepEqual(to12(18), { hour12: 6, period: "PM" });
  assert.equal(to24(12, "AM"), 0);
  assert.equal(to24(6, "AM"), 6);
  assert.equal(to24(12, "PM"), 12);
  assert.equal(to24(6, "PM"), 18);
  assert.equal(formatClock(6, 5), "06:05 AM");
  assert.equal(formatClock(0, 0), "12:00 AM");
});

test("names repeat patterns", () => {
  assert.equal(repeatLabel([]), "Once");
  assert.equal(repeatLabel([1, 2, 3, 4, 5]), "Weekdays");
  assert.equal(repeatLabel([0, 6]), "Weekends");
  assert.equal(repeatLabel([0, 1, 2, 3, 4, 5, 6]), "Every day");
  assert.equal(repeatLabel([1, 3]), "Mon Wed");
});

test("schedules the next weekday and skips a time that already passed", () => {
  const saturdayEvening = new Date(2026, 10, 14, 20, 0, 0);
  const next = nextOccurrence(alarm(), saturdayEvening);
  assert.ok(next);
  assert.equal(next?.getDay(), 1);
  assert.equal(next?.getDate(), 16);
  assert.equal(next?.getHours(), 6);

  const mondayBefore = new Date(2026, 10, 16, 5, 0, 0);
  const laterToday = nextOccurrence(alarm(), mondayBefore);
  assert.equal(laterToday?.getDate(), 16);
  assert.equal(laterToday?.getHours(), 6);

  const exactly = new Date(2026, 10, 16, 6, 0, 0);
  const following = nextOccurrence(alarm(), exactly);
  assert.equal(following?.getDate(), 17);
});

test("arms a one-time alarm for the next future occurrence", () => {
  const morning = new Date(2026, 10, 14, 5, 0, 0);
  assert.equal(initialOnceDate(6, 0, morning), "2026-11-14");
  const after = new Date(2026, 10, 14, 8, 0, 0);
  assert.equal(initialOnceDate(6, 0, after), "2026-11-15");

  const once = alarm({
    repeat: [],
    onceDate: "2026-11-14",
    hour: 18,
    minute: 30,
  });
  const when = nextOccurrence(once, new Date(2026, 10, 14, 8, 0, 0));
  assert.equal(when?.getHours(), 18);
  assert.equal(when?.getMinutes(), 30);
  assert.equal(nextOccurrence(once, new Date(2026, 10, 14, 19, 0, 0)), null);
});

test("turns off a one-time alarm after its minute has passed", () => {
  const once = alarm({ repeat: [], onceDate: "2026-11-14", hour: 6, minute: 0, enabled: true });
  const [expired] = expirePastOnce([once], new Date(2026, 10, 14, 9, 0, 0));
  assert.equal(expired?.enabled, false);
  const normalized = normalizeAlarm({ ...once, repeat: [1, 2, 3, 4, 5], label: "  " }, new Date(2026, 10, 14, 9, 0, 0));
  assert.equal(normalized.label, "Alarm");
  assert.equal(normalized.onceDate, null);
});

test("moves machine mode onto the previous day when the lead crosses midnight", () => {
  const slot = machineWeekly(alarm({ hour: 0, minute: 10, machineLeadMinutes: 20, repeat: [1, 2, 3, 4, 5] }));
  assert.equal(slot.hour, 23);
  assert.equal(slot.minute, 50);
  assert.deepEqual(slot.days, [0, 1, 2, 3, 4]);
  const sameMorning = machineWeekly(alarm({ hour: 6, minute: 0, machineLeadMinutes: 20, repeat: [1, 2, 3, 4, 5] }));
  assert.equal(sameMorning.hour, 5);
  assert.equal(sameMorning.minute, 40);
  assert.deepEqual(sameMorning.days, [1, 2, 3, 4, 5]);
});

test("describes how soon the next ring is", () => {
  const now = new Date(2026, 10, 14, 8, 0, 0);
  assert.equal(relativeRing(new Date(2026, 10, 14, 8, 20, 0), now), "Rings in 20 minutes");
  assert.equal(relativeRing(new Date(2026, 10, 15, 8, 0, 0), now), "Rings tomorrow");
  assert.equal(relativeRing(new Date(2026, 10, 16, 6, 0, 0), now), "Rings Monday");
});

test("treats the alarm minute as due only inside the ring window", () => {
  const target = new Date(2026, 10, 16, 6, 0, 0);
  assert.equal(isDue(target, new Date(2026, 10, 16, 6, 0, 10)), true);
  assert.equal(isDue(target, new Date(2026, 10, 16, 6, 1, 10)), false);
  assert.equal(isDue(target, new Date(2026, 10, 16, 5, 59, 50)), false);
});

test("plans repeating notifications and stays inside the iOS budget", () => {
  const now = new Date(2026, 10, 14, 12, 0, 0);
  const weekday = planNotifications([alarm({ machineLeadMinutes: 10 })], [], now);
  assert.equal(weekday.filter((item) => item.purpose === "alarm").length, 5);
  assert.equal(weekday.filter((item) => item.purpose === "machine").length, 5);
  assert.ok(weekday.every((item) => item.trigger.kind === "weekly"));

  const daily = planNotifications([alarm({ repeat: [0, 1, 2, 3, 4, 5, 6], machineLeadMinutes: 0 })], [], now);
  assert.equal(daily.length, 1);
  assert.equal(daily[0]?.trigger.kind, "daily");

  const many = Array.from({ length: 8 }, (_, index) =>
    alarm({
      id: `a${index}`,
      repeat: [0, 1, 2, 3, 4, 5, 6],
      machineLeadMinutes: 10,
      hour: index,
    }),
  );
  const planned = planNotifications(many, [], now);
  assert.ok(planned.length <= 56);
  assert.equal(planned.filter((item) => item.purpose === "alarm").length, 8);
  assert.equal(planned.filter((item) => item.purpose === "machine").length, 8);

  const disabled = planNotifications([alarm({ enabled: false })], [], now);
  assert.equal(disabled.length, 0);
});
