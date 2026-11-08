import { describe, expect, it } from "vitest";
import { icsCalendar, icsEscape } from "@/lib/ics";
import { makeSub } from "./helpers";

describe("icsCalendar", () => {
  const now = new Date(Date.UTC(2026, 10, 8, 12, 34, 56));

  it("builds an all-day event with a stable uid and CRLF line endings", () => {
    const sub = makeSub({ id: "netflix", name: "Netflix", amount: 22.99, currency: "USD" });
    const text = icsCalendar([{ subscription: sub, date: new Date(2026, 11, 1), record: null }], now);

    expect(text.startsWith("BEGIN:VCALENDAR\r\n")).toBe(true);
    expect(text.endsWith("END:VCALENDAR\r\n")).toBe(true);
    expect(text).toContain("UID:netflix-20261201@kiper");
    expect(text).toContain("DTSTART;VALUE=DATE:20261201");
    expect(text).toContain("DTSTAMP:20261108T123456Z");
    expect(text).toContain("SUMMARY:Списание — Netflix");
    expect(text).toContain("DESCRIPTION:22\\,99 $ · Ежемесячно");
    expect(text).toContain("VERSION:2.0");
    expect(text).toContain("PRODID:-//Kiper//Subscription Calendar//RU");
    // No bare \n anywhere: RFC 5545 requires CRLF.
    expect(text.replace(/\r\n/g, "")).not.toContain("\n");
  });

  it("escapes RFC 5545 special characters in text", () => {
    const sub = makeSub({ id: "a;1", name: 'A\\B, "C"\nD' });
    const text = icsCalendar([{ subscription: sub, date: new Date(2026, 11, 1), record: null }], now);
    expect(text).toContain("SUMMARY:Списание — A\\\\B\\, \"C\"\\nD");
  });

  it("emits one VEVENT per charge with per-day uids", () => {
    const sub = makeSub({ id: "x" });
    const text = icsCalendar(
      [
        { subscription: sub, date: new Date(2026, 11, 1), record: null },
        { subscription: sub, date: new Date(2026, 11, 15), record: null },
      ],
      now,
    );
    expect(text.split("BEGIN:VEVENT").length - 1).toBe(2);
    expect(text).toContain("UID:x-20261201@kiper");
    expect(text).toContain("UID:x-20261215@kiper");
  });
});

describe("icsEscape", () => {
  it("covers backslash, semicolon, comma and newline", () => {
    expect(icsEscape("a\\b;c,d\ne")).toBe("a\\\\b\\;c\\,d\\ne");
  });
});
