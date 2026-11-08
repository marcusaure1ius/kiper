import { describe, expect, it } from "vitest";
import { addDays, addMonths, startOfDay } from "@/lib/date";
import { Subscription } from "@/lib/models";
import { anchor, firstCharge, scheduleDates, step, upcoming } from "@/lib/schedule";

function sub(overrides: Partial<Subscription> = {}): Subscription {
  const start = new Date(2024, 0, 31); // Jan 31 2024
  return {
    id: "s1",
    name: "Test",
    amount: 100,
    currency: "RUB",
    billingPeriod: "monthly",
    customPeriodDays: null,
    categoryId: null,
    nextBillingDate: new Date(2024, 1, 29), // Feb 29 2024 (leap)
    reminderDaysBefore: 1,
    status: "active",
    trialEndDate: null,
    startDate: start,
    note: null,
    domain: null,
    createdAt: start,
    icon: null,
    ...overrides,
  };
}

describe("date math", () => {
  it("clamps month addition like Calendar.current (Jan 31 + 1 = Feb 29 in leap year)", () => {
    expect(addMonths(new Date(2024, 0, 31), 1).getDate()).toBe(29);
    expect(addMonths(new Date(2023, 0, 31), 1).getDate()).toBe(28); // 2023 non-leap
    expect(addMonths(new Date(2024, 0, 31), 2).getDate()).toBe(31); // Mar 31
    expect(addMonths(new Date(2024, 7, 31), 1).getDate()).toBe(30); // Sep 30
  });

  it("startOfDay keeps local time", () => {
    const d = new Date(2024, 5, 15, 18, 44);
    const s = startOfDay(d);
    expect(s.getHours()).toBe(0);
    expect(s.getDate()).toBe(15);
  });
});

describe("Schedule.step", () => {
  it("steps weekly/monthly/annual from base", () => {
    const base = new Date(2024, 0, 10);
    expect(step(base, "weekly", null, 1).getTime()).toBe(addDays(base, 7).getTime());
    expect(step(base, "monthly", null, 3).getMonth()).toBe(3);
    expect(step(base, "annual", null, 2).getFullYear()).toBe(2026);
    expect(step(base, "custom", 14, 1).getTime()).toBe(addDays(base, 14).getTime());
    expect(step(base, "custom", null, 1).getTime()).toBe(addDays(base, 30).getTime()); // default 30
  });
});

describe("Schedule.anchor", () => {
  it("uses startDate when nextBillingDate lies on its grid", () => {
    const s = sub({ startDate: new Date(2024, 0, 15), nextBillingDate: new Date(2024, 1, 15) });
    expect(anchor(s).getTime()).toBe(new Date(2024, 0, 15).getTime());
  });

  it("falls back to nextBillingDate when off-grid", () => {
    const s = sub({ startDate: new Date(2024, 0, 15), nextBillingDate: new Date(2024, 1, 20) });
    expect(anchor(s).getTime()).toBe(new Date(2024, 1, 20).getTime());
  });
});

describe("Schedule.dates", () => {
  it("never returns dates between today and nextBillingDate", () => {
    const now = new Date(2024, 5, 10);
    const s = sub({
      startDate: new Date(2024, 0, 10),
      nextBillingDate: new Date(2024, 5, 15),
    });
    const dates = scheduleDates(s, new Date(2024, 0, 1), new Date(2024, 6, 1), now);
    for (const d of dates) {
      const inGap = d >= startOfDay(now) && d < startOfDay(s.nextBillingDate);
      expect(inGap).toBe(false);
    }
    expect(dates.some((d) => d.getTime() === new Date(2024, 5, 15).getTime())).toBe(true);
    // History follows the anchor grid (Jun 15 off-grid → anchor is nextBillingDate,
    // so the earliest charge is Jan 15), never before startDate.
    expect(dates.some((d) => d.getTime() === new Date(2024, 0, 15).getTime())).toBe(true);
    expect(dates.some((d) => d.getTime() === new Date(2024, 0, 10).getTime())).toBe(false);
  });
});

describe("Schedule.firstCharge", () => {
  it("rolls a past nextBillingDate forward on-grid", () => {
    const now = new Date(2024, 4, 20); // May 20
    const s = sub({ startDate: new Date(2024, 0, 15), nextBillingDate: new Date(2024, 1, 15) });
    const next = firstCharge(s, now);
    expect(next.getTime()).toBe(new Date(2024, 5, 15).getTime()); // Jun 15 — first grid day ≥ May 20
  });
});

describe("Schedule.upcoming", () => {
  it("returns nextBillingDate plus following charges", () => {
    const s = sub({ startDate: new Date(2024, 0, 15), nextBillingDate: new Date(2024, 1, 15) });
    const dates = upcoming(s, 3);
    expect(dates.length).toBe(3);
    expect(dates[0].getMonth()).toBe(1);
    expect(dates[1].getMonth()).toBe(2);
    expect(dates[2].getMonth()).toBe(3);
  });
});
