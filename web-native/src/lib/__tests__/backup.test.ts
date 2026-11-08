import { describe, expect, it } from "vitest";
import {
  BackupError, backupDate, categoryFromDTO, categoryToDTO, decodeBackup,
  decodeCSV, encodeCSV, makeBackupFile, parseCSV, paymentFromDTO, subscriptionFromDTO,
  subscriptionToDTO,
} from "@/lib/backup";
import { makePaymentId } from "@/lib/models";

describe("backupDate", () => {
  it("parses Dart local ISO with millis as local time", () => {
    const d = backupDate("2024-03-01T12:30:45.123");
    expect(d?.getTime()).toBe(new Date(2024, 2, 1, 12, 30, 45, 123).getTime());
  });

  it("parses micros (6 digits) keeping millis", () => {
    const d = backupDate("2024-03-01T12:30:45.123456");
    expect(d?.getMilliseconds()).toBe(123);
  });

  it("parses plain dates as local midnight", () => {
    const d = backupDate("2026-10-13");
    expect(d?.getTime()).toBe(new Date(2026, 9, 13).getTime());
  });

  it("parses zoned ISO as absolute time", () => {
    const d = backupDate("2024-03-01T12:30:45Z");
    expect(d?.toISOString()).toBe("2024-03-01T12:30:45.000Z");
  });

  it("parses space-separated local times", () => {
    const d = backupDate("2024-03-01 12:30:45");
    expect(d?.getTime()).toBe(new Date(2024, 2, 1, 12, 30, 45).getTime());
  });
});

describe("backup round-trip", () => {
  it("subscription DTO → model → DTO is stable", () => {
    const dto = {
      id: "netflix",
      name: "Netflix",
      icon: null,
      amount: 22.99,
      currency: "USD",
      billingPeriod: "monthly",
      customPeriodDays: null,
      categoryId: "cat-streaming",
      nextBillingDate: "2026-11-13T00:00:00.000",
      startDate: "2024-03-01T00:00:00.000",
      status: "active",
      reminderDaysBefore: 1,
      note: null,
      createdAt: "2024-03-01T10:00:00.000",
      domain: "netflix.com",
      trialEndDate: null,
    };
    const sub = subscriptionFromDTO(dto);
    expect(sub).not.toBeNull();
    const back = subscriptionToDTO(sub!);
    expect(back.nextBillingDate).toBe(dto.nextBillingDate);
    expect(back.startDate).toBe(dto.startDate);
    expect(back.currency).toBe("USD");
    expect(back.status).toBe("active");
    expect(back.createdAt).toBe(dto.createdAt);
  });

  it("category ARGB color round-trips", () => {
    const c = categoryFromDTO({ id: "cat1", name: "Test", color: 0xFF7C4DFF | 0, icon: "movie" });
    expect(c.colorHex).toBe(0x7c4dff);
    expect(c.symbol).toBe("play.tv.fill"); // IconMap: movie → play.tv.fill
    const dto = categoryToDTO(c);
    expect((dto.color >>> 0) & 0xffffff).toBe(0x7c4dff);
    expect(dto.icon).toBe("movie");
  });

  it("payment id matches iOS makeId (subscriptionId-yyyy-MM-dd)", () => {
    expect(makePaymentId("abc", new Date(2026, 10, 13))).toBe("abc-2026-11-13");
    const p = paymentFromDTO({
      subscriptionId: "abc", date: "2026-11-13T00:00:00.000", amount: 5, currency: "EUR",
      amountRub: 490, kind: "charge", source: "auto",
    });
    expect(p?.id).toBe(makePaymentId("abc", p!.date));
  });

  it("decode rejects newer versions with a friendly error", () => {
    expect(() => decodeBackup(JSON.stringify({ version: 2, subscriptions: [], categories: [], settings: {} }))).toThrow(BackupError);
    expect(() => decodeBackup("not json")).toThrow(BackupError);
  });

  it("decode tolerates missing keys (Android minimal files)", () => {
    const file = decodeBackup(JSON.stringify({ version: 1, exportedAt: "", subscriptions: [], categories: [], settings: {} }));
    expect(file.payments ?? []).toEqual([]);
  });

  it("unknown enum values fall back instead of breaking the import", () => {
    // A future app version may add currencies/periods/statuses; an older import
    // must degrade gracefully (same rule as iOS/Android).
    const sub = subscriptionFromDTO({
      id: "x", name: "X", amount: 5, currency: "GBP", billingPeriod: "biweekly",
      nextBillingDate: "2026-12-01T00:00:00.000", startDate: "2026-01-01T00:00:00.000",
      status: "archived",
    })!;
    expect(sub.currency).toBe("RUB");
    expect(sub.billingPeriod).toBe("monthly");
    expect(sub.status).toBe("active");
    const p = paymentFromDTO({
      subscriptionId: "x", date: "2026-11-13T00:00:00.000", amount: 5, currency: "CHF",
      amountRub: 450, kind: "refund", source: "carrier",
    })!;
    expect(p.kind).toBe("charge");
    expect(p.source).toBe("auto");
    expect(p.currency).toBe("RUB");
  });

  it("offset-zone timestamps are absolute instants, not local time", () => {
    expect(backupDate("2026-10-13T12:00:00+05:00")?.toISOString()).toBe("2026-10-13T07:00:00.000Z");
    expect(backupDate("2026-10-13T12:00:00-0800")?.toISOString()).toBe("2026-10-13T20:00:00.000Z");
  });

  it("makeBackupFile → decodeBackup round-trips", () => {
    const sub = subscriptionFromDTO({
      id: "a", name: "A", amount: 9.99, currency: "USD", billingPeriod: "monthly",
      nextBillingDate: "2026-12-01T00:00:00.000", startDate: "2026-01-01T00:00:00.000",
    })!;
    const file = makeBackupFile({
      subscriptions: [sub],
      categories: [{ id: "c1", name: "C", colorHex: 0x112233, symbol: "sparkles" }],
      settings: { budgetRub: "15000" },
      payments: [],
    });
    const decoded = decodeBackup(JSON.stringify(file));
    expect(decoded.settings["budgetRub"]).toBe("15000");
    expect(decoded.subscriptions[0].amount).toBeCloseTo(9.99);
    expect(decoded.categories[0].icon).toBe("smart_toy"); // sparkles → smart_toy
  });
});

describe("CSV", () => {
  it("parses RFC 4180 with quotes and newlines", () => {
    const rows = parseCSV('a,b\n"x,1","line1\nline2"\n"""",c');
    expect(rows[0]).toEqual(["a", "b"]);
    expect(rows[1]).toEqual(["x,1", "line1\nline2"]);
    expect(rows[2]).toEqual(['"', "c"]);
  });

  it("skips BOM and keeps trailing empty rows out", () => {
    const rows = parseCSV("\uFEFFa,b\n1,2\n");
    expect(rows.length).toBe(2);
  });

  it("encode → decode round-trips subscriptions", () => {
    const sub = subscriptionFromDTO({
      id: "mts", name: "МТС", amount: 890, currency: "RUB", billingPeriod: "monthly",
      nextBillingDate: "2026-11-09T00:00:00.000", startDate: "2020-06-01T00:00:00.000",
      note: "note, with comma",
    })!;
    const text = encodeCSV([sub]);
    const decoded = decodeCSV(text);
    expect(decoded.length).toBe(1);
    expect(decoded[0].name).toBe("МТС");
    expect(decoded[0].amount).toBeCloseTo(890);
    expect(decoded[0].note).toBe("note, with comma");
    expect(decoded[0].currency).toBe("RUB");
  });

  it("whole amounts serialize with one decimal like iOS %.1f", () => {
    const sub = subscriptionFromDTO({
      id: "x", name: "X", amount: 20, currency: "USD", billingPeriod: "monthly",
      nextBillingDate: "2026-12-01T00:00:00.000", startDate: "2026-01-01T00:00:00.000",
    })!;
    expect(encodeCSV([sub]).split("\n")[1]).toContain(",20.0,");
  });

  it("rows without id/name are skipped", () => {
    const decoded = decodeCSV("id,name\n,noname\nok,Named\n");
    expect(decoded.length).toBe(1);
    expect(decoded[0].id).toBe("ok");
  });
});
