// Calendar math used by the schedule port. Everything works in the local time
// zone, like Calendar.current in the iOS app. Month/year additions clamp the
// day (Jan 31 + 1 month → Feb 28), matching DateComponents arithmetic.

export function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function addDays(d: Date, n: number): Date {
  const r = new Date(d.getFullYear(), d.getMonth(), d.getDate(),
    d.getHours(), d.getMinutes(), d.getSeconds(), d.getMilliseconds());
  r.setDate(r.getDate() + n);
  return r;
}

function daysInMonth(year: number, month: number): number {
  return new Date(year, month + 1, 0).getDate();
}

export function addMonths(d: Date, n: number): Date {
  const target = new Date(d.getFullYear(), d.getMonth() + n, 1,
    d.getHours(), d.getMinutes(), d.getSeconds(), d.getMilliseconds());
  target.setDate(Math.min(d.getDate(), daysInMonth(target.getFullYear(), target.getMonth())));
  return target;
}

export function addYears(d: Date, n: number): Date {
  const target = new Date(d.getFullYear(), d.getMonth(), 1,
    d.getHours(), d.getMinutes(), d.getSeconds(), d.getMilliseconds());
  target.setFullYear(target.getFullYear() + n);
  target.setDate(Math.min(d.getDate(), daysInMonth(target.getFullYear(), target.getMonth())));
  return target;
}

export function sameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/// Whole days from `from` to `to` (day boundaries, DST-safe).
export function daysBetween(from: Date, to: Date): number {
  const index = (d: Date) => Math.round(new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() / 86400000);
  return index(to) - index(from);
}
