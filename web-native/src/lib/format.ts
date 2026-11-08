// Port of ios-native/Kiper/Shared/Formatting.swift (Fmt) — ru_RU everywhere.

import { daysBetween } from "./date";
import { currencySymbol, Currency } from "./models";

const ru = "ru-RU";

/// `1 234,56 ₽` / `1 234 ₽` — space thousands, comma decimals.
export function money(amount: number, currency: Currency, decimals?: number): string {
  const d = decimals ?? (Math.round(amount) === amount ? 0 : 2);
  const number = new Intl.NumberFormat(ru, { minimumFractionDigits: d, maximumFractionDigits: d }).format(amount);
  return `${number} ${currencySymbol[currency]}`;
}

export function rub(amount: number): string {
  return money(amount, "RUB", 0);
}

const dayFormatter = new Intl.DateTimeFormat(ru, { day: "numeric", month: "long" });
const fullFormatter = new Intl.DateTimeFormat(ru, { day: "numeric", month: "long", year: "numeric" });
const shortMonthFormatter = new Intl.DateTimeFormat(ru, { month: "short" });

/// «8 ноября»
export function day(date: Date): string {
  return dayFormatter.format(date);
}

/// «8 ноября 2026 г.»
export function fullDate(date: Date): string {
  return fullFormatter.format(date);
}

/// «8 ноября», or «8 ноября 2027 г.» when not the current year.
export function smartDate(date: Date, now: Date = new Date()): string {
  return date.getFullYear() === now.getFullYear() ? day(date) : fullDate(date);
}

/// «Ноябрь» (nominative, capitalized).
export function monthName(date: Date): string {
  const name = new Intl.DateTimeFormat(ru, { month: "long" }).format(date);
  return name.charAt(0).toUpperCase() + name.slice(1);
}

/// «ноябре» — for phrases like «оплачено в ноябре».
export function monthPrepositional(date: Date): string {
  const names = ["январе", "феврале", "марте", "апреле", "мае", "июне",
    "июле", "августе", "сентябре", "октябре", "ноябре", "декабре"];
  return names[date.getMonth()];
}

export function monthShort(date: Date): string {
  return shortMonthFormatter.format(date).replace(".", "");
}

/// Russian plural: plural(5, "списание", "списания", "списаний") → «списаний».
export function plural(n: number, one: string, few: string, many: string): string {
  const n10 = n % 10, n100 = n % 100;
  if (n10 === 1 && n100 !== 11) return one;
  if (n10 >= 2 && n10 <= 4 && !(n100 >= 12 && n100 <= 14)) return few;
  return many;
}

/// «Сегодня», «Завтра», «Через 5 дн.», «3 дн. назад».
export function relative(date: Date, now: Date = new Date()): string {
  const days = daysBetween(now, date);
  if (days === 0) return "Сегодня";
  if (days === 1) return "Завтра";
  if (days === -1) return "Вчера";
  if (days > 1) return `Через ${days} дн.`;
  return `${-days} дн. назад`;
}
