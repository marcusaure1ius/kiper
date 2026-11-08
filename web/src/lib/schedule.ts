// Port of ios-native/Kiper/Data/Schedule.swift. Dates are always
// `anchor + n × period` (never stepped one by one), so a monthly charge on the
// 31st stays on the 31st (Jan 31 → Feb 28 → Mar 31).

import { addDays, addMonths, addYears, sameDay, startOfDay } from "./date";
import { BillingPeriod, Subscription } from "./models";

export function step(base: Date, period: BillingPeriod, customDays: number | null, n: number): Date {
  switch (period) {
    case "weekly": return addDays(base, 7 * n);
    case "monthly": return addMonths(base, n);
    case "quarterly": return addMonths(base, 3 * n);
    case "semiannual": return addMonths(base, 6 * n);
    case "annual": return addYears(base, n);
    case "custom": return addDays(base, Math.max(customDays ?? 30, 1) * n);
  }
}

function stepSub(sub: Subscription, base: Date, n: number): Date {
  return step(base, sub.billingPeriod, sub.customPeriodDays, n);
}

export function anchor(sub: Subscription): Date {
  const next = startOfDay(sub.nextBillingDate);
  if (!(sub.startDate <= sub.nextBillingDate)) return sub.nextBillingDate;
  for (let n = 0; n < 10000; n++) {
    const day = startOfDay(stepSub(sub, sub.startDate, n));
    if (sameDay(day, next)) return sub.startDate;
    if (day > next) break;
  }
  return sub.nextBillingDate;
}

/// Charges in [from, to): history goes back to startDate; nothing between today
/// and nextBillingDate; future charges start exactly at nextBillingDate.
export function scheduleDates(sub: Subscription, from: Date, to: Date, now: Date = new Date()): Date[] {
  const base = anchor(sub);
  const lower = maxDate(from, startOfDay(sub.startDate));
  const today = startOfDay(now);
  const next = startOfDay(sub.nextBillingDate);
  let n = 0;
  while (n > -10000 && stepSub(sub, base, n - 1) >= lower) n -= 1;
  const result: Date[] = [];
  while (n < 10000) {
    const date = stepSub(sub, base, n);
    if (date >= to) break;
    if (date >= lower && !(date >= today && date < next)) result.push(date);
    n += 1;
  }
  return result;
}

/// First grid date on or after `day` (used to roll a past nextBillingDate forward).
export function firstCharge(sub: Subscription, onOrAfter: Date): Date {
  const base = anchor(sub);
  const target = startOfDay(onOrAfter);
  for (let n = 0; n < 10000; n++) {
    const date = stepSub(sub, base, n);
    if (startOfDay(date) >= target) return date;
  }
  return sub.nextBillingDate;
}

/// nextBillingDate and the following count-1 charges.
export function upcoming(sub: Subscription, count: number): Date[] {
  const base = anchor(sub);
  const next = startOfDay(sub.nextBillingDate);
  const result: Date[] = [];
  let n = 0;
  while (result.length < count && n < 10000) {
    const date = stepSub(sub, base, n);
    if (startOfDay(date) >= next) result.push(date);
    n += 1;
  }
  return result;
}

function maxDate(a: Date, b: Date): Date {
  return a >= b ? a : b;
}
