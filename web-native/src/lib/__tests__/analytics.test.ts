// Pure analytics/store derivations — the calculations behind the Analytics
// screen. Fixed dates; `now` is always injected so nothing is time-flaky.

import { describe, expect, it } from "vitest";
import {
  annualForecast, categoryShares, duplicateGroups, monthOverMonth, monthProgress,
  monthlyTotalRub, monthlyTotals,
} from "@/lib/store";
import { makePayment, makeSub, rates } from "./helpers";

// 2026-11-20 12:00 local — mid-month, deterministic.
const NOW = new Date(2026, 10, 20, 12, 0, 0);

describe("monthlyTotalRub", () => {
  it("normalises periods to a monthly steady state, RUB only for active subs", () => {
    const s = {
      subscriptions: [
        makeSub({ id: "a", amount: 1000, billingPeriod: "monthly" }),
        makeSub({ id: "b", amount: 12000, billingPeriod: "annual" }),
        makeSub({ id: "c", amount: 100, billingPeriod: "weekly", status: "paused" }),
      ],
      rateSnapshot: rates,
    };
    expect(monthlyTotalRub(s)).toBeCloseTo(2000);
  });

  it("converts foreign currencies with the snapshot rates", () => {
    const s = {
      subscriptions: [makeSub({ amount: 10, currency: "USD", billingPeriod: "monthly" })],
      rateSnapshot: rates,
    };
    expect(monthlyTotalRub(s)).toBeCloseTo(900);
  });
});

describe("monthProgress", () => {
  it("splits the month into paid and remaining around today", () => {
    const s = {
      subscriptions: [
        // Monthly on the 5th: Nov 5 already happened, Dec 5 is outside November.
        makeSub({ id: "a", amount: 500, startDate: new Date(2026, 0, 5), nextBillingDate: new Date(2026, 11, 5) }),
        // Trial whose first charge lands later this month.
        makeSub({
          id: "t", amount: 200, status: "trial", trialEndDate: new Date(2026, 10, 25),
          startDate: new Date(2026, 9, 1), nextBillingDate: new Date(2026, 10, 25),
        }),
      ],
      payments: [makePayment("a", new Date(2026, 10, 5))],
      rateSnapshot: rates,
    };
    const { paid, remaining } = monthProgress(s, NOW);
    expect(paid).toBeCloseTo(500);
    expect(remaining).toBeCloseTo(200);
  });

  it("a recorded skip counts as paid zero, not as the subscription amount", () => {
    const s = {
      subscriptions: [makeSub({ id: "a", amount: 500, startDate: new Date(2026, 0, 5), nextBillingDate: new Date(2026, 11, 5) })],
      payments: [makePayment("a", new Date(2026, 10, 5), { kind: "skip", amountRub: 0 })],
      rateSnapshot: rates,
    };
    expect(monthProgress(s, NOW).paid).toBe(0);
  });
});

describe("monthlyTotals", () => {
  it("marks the current and future buckets as forecast", () => {
    const s = {
      subscriptions: [makeSub({ id: "a", amount: 500, startDate: new Date(2026, 0, 5), nextBillingDate: new Date(2026, 11, 5) })],
      payments: [makePayment("a", new Date(2026, 10, 5))],
      rateSnapshot: rates,
    };
    const totals = monthlyTotals(s, 2, 1, NOW);
    expect(totals).toHaveLength(4);
    expect(totals.map((t) => t.isForecast)).toEqual([false, false, true, true]);
    expect(totals[2].amount).toBeCloseTo(500); // current month, already charged
    expect(totals[3].amount).toBeCloseTo(500); // December, planned
  });
});

describe("monthOverMonth", () => {
  it("compares the same span of the month, not full months", () => {
    const s = {
      subscriptions: [makeSub({ id: "a", amount: 500, startDate: new Date(2026, 0, 5), nextBillingDate: new Date(2026, 11, 5) })],
      payments: [],
      rateSnapshot: rates,
    };
    // Both spans hold exactly one charge (Nov 5 and Oct 5) — delta must be 0.
    expect(monthOverMonth(s, NOW)).toEqual({ current: 500, previous: 500, delta: 0 });
  });

  it("a skip drops this month against the previous one", () => {
    const s = {
      subscriptions: [makeSub({ id: "a", amount: 500, startDate: new Date(2026, 0, 5), nextBillingDate: new Date(2026, 11, 5) })],
      payments: [makePayment("a", new Date(2026, 10, 5), { kind: "skip", amountRub: 0 })],
      rateSnapshot: rates,
    };
    expect(monthOverMonth(s, NOW)).toEqual({ current: 0, previous: 500, delta: -500 });
  });

  it("is hidden when nothing was charged in either span", () => {
    expect(monthOverMonth({ subscriptions: [], payments: [], rateSnapshot: rates }, NOW)).toBeNull();
  });
});

describe("categoryShares", () => {
  it("splits paid vs total per category inside the interval", () => {
    const s = {
      subscriptions: [
        makeSub({ id: "a", amount: 500, categoryId: "c1", startDate: new Date(2026, 0, 5), nextBillingDate: new Date(2026, 11, 5) }),
        makeSub({ id: "b", amount: 300, categoryId: "c2", startDate: new Date(2026, 0, 25), nextBillingDate: new Date(2026, 10, 25) }),
        makeSub({ id: "c", amount: 100, categoryId: null, startDate: new Date(2026, 1, 15), nextBillingDate: new Date(2026, 11, 15) }),
      ],
      categories: [
        { id: "c1", name: "Видео", colorHex: 0x7c4dff, symbol: "play.tv.fill" },
        { id: "c2", name: "Музыка", colorHex: 0x00ff00, symbol: "music.note" },
      ],
      payments: [makePayment("a", new Date(2026, 10, 5))],
      rateSnapshot: rates,
    };
    const shares = categoryShares(s, new Date(2026, 10, 1), new Date(2026, 11, 1), NOW);
    expect(shares).toHaveLength(3);
    expect(shares[0]).toEqual({ category: s.categories[0], paid: 500, total: 500 });
    // Charged on the 25th — after `now`, so planned but not paid yet.
    expect(shares[1].total).toBeCloseTo(300);
    expect(shares[1].paid).toBe(0);
    // No category → null; charged on Nov 15, already paid.
    expect(shares[2]).toEqual({ category: null, paid: 100, total: 100 });
  });
});

describe("annualForecast", () => {
  it("ranks subscriptions by their yearly RUB cost", () => {
    const s = {
      subscriptions: [
        makeSub({ id: "a", amount: 300, billingPeriod: "monthly" }),          // 3600 / yr
        makeSub({ id: "b", amount: 10, currency: "USD", billingPeriod: "monthly" }), // 10800 / yr
        makeSub({ id: "c", amount: 12000, billingPeriod: "annual" }),         // 12000 / yr
        makeSub({ id: "d", amount: 999, status: "cancelled", billingPeriod: "monthly" }),
      ],
      rateSnapshot: rates,
    };
    const { totalRub, top } = annualForecast(s);
    expect(totalRub).toBeCloseTo(12000 + 10800 + 3600);
    expect(top.map((t) => t.subscription.id)).toEqual(["c", "b", "a"]);
  });
});

describe("duplicateGroups", () => {
  it("groups by domain first, then by name containment within a category", () => {
    const s = {
      subscriptions: [
        makeSub({ id: "1", name: "Netflix", domain: "netflix.com" }),
        makeSub({ id: "2", name: "Netflix Premium", domain: "netflix.com", categoryId: "video" }),
        makeSub({ id: "3", name: "Яндекс.Музыка", domain: "music.yandex.ru", categoryId: "music" }),
        makeSub({ id: "4", name: "Яндекс", domain: "yandex.ru", categoryId: "music" }),
        makeSub({ id: "5", name: "Netflix Mobile", domain: "netflix.com", status: "cancelled" }),
      ],
    };
    const groups = duplicateGroups(s);
    expect(groups).toHaveLength(2);
    expect(groups[0].map((x) => x.id)).toEqual(["1", "2"]);
    expect(groups[1].map((x) => x.id)).toEqual(["3", "4"]);
  });

  it("ignores short names to avoid false containment hits", () => {
    const s = {
      subscriptions: [
        makeSub({ id: "1", name: "VK", categoryId: "c" }),
        makeSub({ id: "2", name: "VK Музыка", categoryId: "c" }),
      ],
    };
    expect(duplicateGroups(s)).toHaveLength(0); // "vk" is 2 chars — too short to match
  });
});
