// Port of ios-native/Kiper/Data/ICSExport.swift — all-day VEVENT per charge.

import { ymd } from "./models";
import { money } from "./format";
import { periodLabel, BillingPeriod, PaymentEvent } from "./models";

function utcStamp(date: Date): string {
  return date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
}

/// RFC 5545 §3.3.11: backslash, semicolon, comma and newlines are escaped.
export function icsEscape(text: string): string {
  return text
    .replaceAll("\\", "\\\\")
    .replaceAll(";", "\\;")
    .replaceAll(",", "\\,")
    .replaceAll("\n", "\\n");
}

export function icsCalendar(events: PaymentEvent[], now: Date = new Date()): string {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Kiper//Subscription Calendar//RU",
    "CALSCALE:GREGORIAN",
  ];
  const stamp = utcStamp(now);
  for (const event of events) {
    const sub = event.subscription;
    lines.push(
      "BEGIN:VEVENT",
      `UID:${sub.id}-${ymd(event.date)}@kiper`,
      `DTSTAMP:${stamp}`,
      `DTSTART;VALUE=DATE:${ymd(event.date)}`,
      `SUMMARY:${icsEscape(`Списание — ${sub.name}`)}`,
      `DESCRIPTION:${icsEscape(`${money(sub.amount, sub.currency)} · ${periodLabel[sub.billingPeriod as BillingPeriod]}`)}`,
      "END:VEVENT",
    );
  }
  lines.push("END:VCALENDAR");
  return lines.join("\r\n") + "\r\n";
}
