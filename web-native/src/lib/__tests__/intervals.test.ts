import { describe, expect, it } from "vitest";
import { endOfMonth, startOfMonth, startOfWeekISO } from "@/lib/intervals";
import { addDays } from "@/lib/date";

describe("intervals", () => {
  it("startOfMonth moves any day to the 1st", () => {
    const m = startOfMonth(new Date(2026, 10, 20));
    expect([m.getFullYear(), m.getMonth(), m.getDate()]).toEqual([2026, 10, 1]);
  });

  it("endOfMonth is exclusive: the 1st of the next month", () => {
    const end = endOfMonth(new Date(2026, 10, 20)); // December
    expect(end.getMonth()).toBe(11);
    expect(end.getDate()).toBe(1);
  });

  it("startOfWeekISO snaps to Monday", () => {
    // 2026-11-08 is a Sunday; its ISO week started Monday 2026-11-02.
    const w = startOfWeekISO(new Date(2026, 10, 8));
    expect([w.getFullYear(), w.getMonth(), w.getDate()]).toEqual([2026, 10, 2]);
    // Wednesday lands on the same Monday.
    expect(startOfWeekISO(new Date(2026, 10, 4)).getDate()).toBe(2);
  });

  it("startOfWeekISO is Monday-first for every weekday of a week", () => {
    const monday = new Date(2026, 10, 2);
    for (let i = 0; i < 7; i++) {
      const snapped = startOfWeekISO(addDays(monday, i));
      expect(snapped.getDay()).toBe(1);
      expect(snapped.getTime()).toBe(monday.getTime());
    }
  });
});
