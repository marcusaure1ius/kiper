// Port of ios-native/Kiper/Data/Backup.swift — the cross-platform backup
// format v1 shared with the Android app, plus the CSV codec.

import { catalogEntryByName } from "./catalog";
import { addDays } from "./date";
import {
  BillingPeriod, Category, Currency, CURRENCIES, PaymentKind, PaymentRecord, PaymentSource,
  PERIODS, STATUSES, Subscription, SubscriptionStatus, makePaymentId,
} from "./models";

export const BACKUP_VERSION = 1;

export interface SubscriptionDTO {
  id: string;
  name: string;
  icon?: string | null;
  amount: number;
  currency: string;
  billingPeriod: string;
  customPeriodDays?: number | null;
  categoryId?: string | null;
  nextBillingDate: string;
  startDate: string;
  status?: string | null;
  reminderDaysBefore?: number | null;
  note?: string | null;
  createdAt?: string | null;
  domain?: string | null;
  trialEndDate?: string | null;
}

export interface CategoryDTO {
  id: string;
  name: string;
  /// ARGB int, e.g. 0xFF7C4DFF.
  color: number;
  /// Material icon name (Android) or SF Symbol name (iOS).
  icon: string;
}

export interface PaymentRecordDTO {
  subscriptionId: string;
  date: string;
  amount: number;
  currency: string;
  amountRub: number;
  kind: string;
  source: string;
}

export interface BackupFileV1 {
  version: number;
  exportedAt: string;
  subscriptions: SubscriptionDTO[];
  categories: CategoryDTO[];
  settings: Record<string, string>;
  payments?: PaymentRecordDTO[] | null;
}

export type BackupErrorKind = "unsupportedVersion" | "unreadable";

export class BackupError extends Error {
  kind: BackupErrorKind;
  constructor(kind: BackupErrorKind, message: string) {
    super(message);
    this.kind = kind;
  }
}

// MARK: - Dates

/// Dart's DateTime.toIso8601String() for local times: 2024-03-01T00:00:00.000.
export function backupDateString(date: Date): string {
  const pad = (n: number, w = 2) => String(n).padStart(w, "0");
  return `${pad(date.getFullYear(), 4)}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}.${pad(date.getMilliseconds(), 3)}`;
}

const ZONED = /(?:Z|[+-]\d{2}:?\d{2})$/;

function parseInto(date: Date, text: string): Date | null {
  const m = text.match(/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?)?$/);
  if (!m) return null;
  const ms = m[7] ? Number(m[7].padEnd(3, "0").slice(0, 3)) : 0;
  date.setFullYear(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  date.setHours(m[4] ? Number(m[4]) : 0, m[5] ? Number(m[5]) : 0, m[6] ? Number(m[6]) : 0, ms);
  return date;
}

/// Accepts Dart local ISO strings (with or without millis/micros), plain dates
/// and full ISO 8601 with a zone. Zoneless strings are local time.
export function backupDate(text: string): Date | null {
  const trimmed = text.trim();
  if (ZONED.test(trimmed) && trimmed.length > 10) {
    const parsed = new Date(trimmed);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  const local = parseInto(new Date(), trimmed);
  return local && !Number.isNaN(local.getTime()) ? local : null;
}

// MARK: - Icon map (Android Material names ↔ SF Symbols)

const iconPairs: [material: string, symbol: string][] = [
  ["movie", "play.tv.fill"],
  ["smart_toy", "sparkles"],
  ["phone_android", "antenna.radiowaves.left.and.right"],
  ["sports_esports", "gamecontroller.fill"],
  ["category", "square.grid.2x2.fill"],
  ["music_note", "music.note"],
  ["book", "book.fill"],
  ["cloud", "cloud.fill"],
  ["security", "lock.shield.fill"],
  ["shopping_bag", "bag.fill"],
];

export const fallbackSymbol = "square.grid.2x2.fill";

export function materialToSymbol(icon: string): string {
  return iconPairs.find(([m]) => m === icon)?.[1] ?? icon;
}

export function symbolToMaterial(symbol: string): string {
  return iconPairs.find(([, s]) => s === symbol)?.[0] ?? symbol;
}

function knownSymbol(name: string | undefined): string {
  if (!name) return fallbackSymbol;
  return materialToSymbol(name);
}

// MARK: - Mapping

export function categoryFromDTO(d: CategoryDTO): Category {
  return { id: d.id, name: d.name, colorHex: (d.color >>> 0) & 0xFFFFFF, symbol: knownSymbol(d.icon) };
}

export function categoryToDTO(c: Category): CategoryDTO {
  return { id: c.id, name: c.name, color: (0xFF000000 | c.colorHex) | 0, icon: symbolToMaterial(c.symbol) };
}

export function subscriptionFromDTO(d: SubscriptionDTO): Subscription | null {
  const next = backupDate(d.nextBillingDate);
  const start = backupDate(d.startDate);
  if (!next || !start) return null;
  const currency = CURRENCIES.find((c) => c === d.currency.toUpperCase()) ?? "RUB";
  const period = PERIODS.find((p) => p === d.billingPeriod) ?? "monthly";
  const status = STATUSES.find((s) => s === d.status) ?? "active";
  return {
    id: d.id,
    name: d.name,
    amount: d.amount,
    currency,
    billingPeriod: period,
    customPeriodDays: d.customPeriodDays ?? null,
    categoryId: d.categoryId ?? null,
    nextBillingDate: next,
    reminderDaysBefore: d.reminderDaysBefore ?? 1,
    status,
    trialEndDate: d.trialEndDate ? backupDate(d.trialEndDate) : null,
    startDate: start,
    note: d.note ?? null,
    domain: d.domain ?? catalogEntryByName(d.name)?.domain ?? null,
    createdAt: d.createdAt ? (backupDate(d.createdAt) ?? new Date()) : new Date(),
    icon: d.icon ?? null,
  };
}

export function subscriptionToDTO(s: Subscription): SubscriptionDTO {
  return {
    id: s.id,
    name: s.name,
    icon: s.icon,
    amount: s.amount,
    currency: s.currency,
    billingPeriod: s.billingPeriod,
    customPeriodDays: s.customPeriodDays,
    categoryId: s.categoryId,
    nextBillingDate: backupDateString(s.nextBillingDate),
    startDate: backupDateString(s.startDate),
    status: s.status,
    reminderDaysBefore: s.reminderDaysBefore,
    note: s.note,
    createdAt: backupDateString(s.createdAt),
    domain: s.domain,
    trialEndDate: s.trialEndDate ? backupDateString(s.trialEndDate) : null,
  };
}

export function paymentFromDTO(d: PaymentRecordDTO): PaymentRecord | null {
  const date = backupDate(d.date);
  if (!date) return null;
  return {
    id: makePaymentId(d.subscriptionId, date),
    subscriptionId: d.subscriptionId,
    date,
    amount: d.amount,
    currency: CURRENCIES.find((c) => c === d.currency.toUpperCase()) ?? "RUB",
    amountRub: d.amountRub,
    kind: d.kind === "skip" ? "skip" : "charge",
    source: (["auto", "manual", "bank"] as PaymentSource[]).find((s) => s === d.source) ?? "auto",
  };
}

export function paymentToDTO(p: PaymentRecord): PaymentRecordDTO {
  return {
    subscriptionId: p.subscriptionId,
    date: backupDateString(p.date),
    amount: p.amount,
    currency: p.currency,
    amountRub: p.amountRub,
    kind: p.kind,
    source: p.source,
  };
}

export interface BackupInput {
  subscriptions: Subscription[];
  categories: Category[];
  settings?: Record<string, string>;
  payments?: PaymentRecord[];
}

export function makeBackupFile(input: BackupInput, now: Date = new Date()): BackupFileV1 {
  return {
    version: BACKUP_VERSION,
    exportedAt: backupDateString(now),
    subscriptions: input.subscriptions.map(subscriptionToDTO),
    categories: input.categories.map(categoryToDTO),
    settings: input.settings ?? {},
    payments: (input.payments ?? []).map(paymentToDTO),
  };
}

export function encodeBackup(file: BackupFileV1): string {
  return JSON.stringify(file, null, 2);
}

export function decodeBackup(text: string): BackupFileV1 {
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    throw new BackupError("unreadable", "Не удалось прочитать файл. Нужен JSON или CSV, экспортированный из Кипера.");
  }
  if (typeof raw !== "object" || raw === null) {
    throw new BackupError("unreadable", "Не удалось прочитать файл. Нужен JSON или CSV, экспортированный из Кипера.");
  }
  const c = raw as Record<string, unknown>;
  const version = typeof c.version === "number" ? c.version : 0;
  if (version > BACKUP_VERSION) {
    throw new BackupError("unsupportedVersion", `Файл из более новой версии приложения (формат ${version}).`);
  }
  const str = (v: unknown): string => (typeof v === "string" ? v : "");
  const subscriptions = Array.isArray(c.subscriptions) ? (c.subscriptions as SubscriptionDTO[]) : [];
  const categories = Array.isArray(c.categories) ? (c.categories as CategoryDTO[]) : [];
  const settings =
    typeof c.settings === "object" && c.settings !== null
      ? (Object.fromEntries(
          Object.entries(c.settings as Record<string, unknown>).filter(([, v]) => typeof v === "string"),
        ) as Record<string, string>)
      : {};
  const payments = Array.isArray(c.payments) ? (c.payments as PaymentRecordDTO[]) : [];
  return { version, exportedAt: str(c.exportedAt), subscriptions, categories, settings, payments };
}

// MARK: - CSV

const csvHeaders = [
  "id", "name", "amount", "currency", "billingPeriod",
  "customPeriodDays", "categoryId", "nextBillingDate",
  "startDate", "status", "reminderDaysBefore", "note", "trialEndDate",
];

function csvNumber(value: number): string {
  return Math.round(value) === value ? value.toFixed(1) : String(value);
}

function csvEscape(value: string): string {
  if (!value.includes(",") && !value.includes('"') && !value.includes("\n")) return value;
  return `"${value.replaceAll('"', '""')}"`;
}

export function encodeCSV(subscriptions: Subscription[]): string {
  const lines = [csvHeaders.join(",")];
  for (const s of subscriptions) {
    const d = subscriptionToDTO(s);
    const values: (string | number | null | undefined)[] = [
      d.id, d.name, csvNumber(d.amount), d.currency, d.billingPeriod,
      d.customPeriodDays, d.categoryId, d.nextBillingDate,
      d.startDate, d.status, d.reminderDaysBefore, d.note, d.trialEndDate,
    ];
    lines.push(values.map((v) => csvEscape(v == null ? "" : String(v))).join(","));
  }
  return lines.join("\n") + "\n";
}

/// RFC 4180-ish parser: quoted fields, escaped quotes, newlines inside quotes.
export function parseCSV(text: string): string[][] {
  const clean = text.replaceAll("\r\n", "\n").replace(/^\uFEFF/, "");
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let inQuotes = false;
  let i = 0;
  while (i < clean.length) {
    const ch = clean[i];
    if (inQuotes) {
      if (ch === '"') {
        if (i + 1 < clean.length && clean[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === ",") {
      row.push(field);
      field = "";
    } else if (ch === "\n") {
      row.push(field);
      field = "";
      if (!(row.length === 1 && row[0] === "")) rows.push(row);
      row = [];
    } else {
      field += ch;
    }
    i += 1;
  }
  if (field !== "" || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

/// Rows that have at least id and name; invalid rows are skipped (like Android).
export function decodeCSV(text: string, now: Date = new Date()): Subscription[] {
  const rows = parseCSV(text);
  const header = rows[0];
  if (!header) return [];
  return rows.slice(1).flatMap((row) => {
    const map: Record<string, string> = {};
    header.forEach((key, i) => {
      if (i < row.length && row[i] !== "") map[key.trim()] = row[i];
    });
    const id = map["id"];
    const name = map["name"];
    if (!id || !name) return [];
    const dto: SubscriptionDTO = {
      id,
      name,
      icon: null,
      amount: Number.parseFloat(map["amount"] ?? "") || 0,
      currency: map["currency"] ?? "RUB",
      billingPeriod: map["billingPeriod"] ?? "monthly",
      customPeriodDays: map["customPeriodDays"] ? Number.parseInt(map["customPeriodDays"]) : null,
      categoryId: map["categoryId"],
      nextBillingDate: map["nextBillingDate"] ?? backupDateString(addDays(now, 30)),
      startDate: map["startDate"] ?? backupDateString(now),
      status: map["status"],
      reminderDaysBefore: map["reminderDaysBefore"] ? Number.parseInt(map["reminderDaysBefore"]) : null,
      note: map["note"],
      createdAt: null,
      domain: null,
      trialEndDate: map["trialEndDate"],
    };
    const sub = subscriptionFromDTO(dto);
    return sub ? [sub] : [];
  });
}
