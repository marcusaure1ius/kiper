// Month/week interval helpers matching Calendar.current dateInterval(of:) and
// the ISO8601 (Monday-first) calendar used for weekly analytics.

import { addDays, startOfDay } from "./date";

export function startOfMonth(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

/// Exclusive end, like DateInterval.end in Swift.
export function endOfMonth(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth() + 1, 1);
}

export function startOfWeekISO(d: Date): Date {
  const day = startOfDay(d);
  const weekday = (day.getDay() + 6) % 7; // 0 = Monday
  return addDays(day, -weekday);
}

/// prevMonth.start + (today − month.start), like the Swift span comparison.
export function daysBetweenSafe(prevMonthStart: Date, today: Date, monthStart: Date): Date {
  return new Date(prevMonthStart.getTime() + (today.getTime() - monthStart.getTime()));
}
