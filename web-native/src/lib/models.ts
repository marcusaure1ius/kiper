// Port of ios-native/Kiper/Models/Models.swift (minus SwiftUI bits).

export const CURRENCIES = ["RUB", "USD", "EUR"] as const;
export type Currency = (typeof CURRENCIES)[number];

export const currencySymbol: Record<Currency, string> = { RUB: "₽", USD: "$", EUR: "€" };

export const PERIODS = ["weekly", "monthly", "quarterly", "semiannual", "annual", "custom"] as const;
export type BillingPeriod = (typeof PERIODS)[number];

export const periodLabel: Record<BillingPeriod, string> = {
  weekly: "Еженедельно",
  monthly: "Ежемесячно",
  quarterly: "Раз в квартал",
  semiannual: "Раз в полгода",
  annual: "Ежегодно",
  custom: "Свой период",
};

export function monthlyEquivalent(p: BillingPeriod): number {
  switch (p) {
    case "weekly": return 52.0 / 12.0;
    case "monthly": return 1;
    case "quarterly": return 1.0 / 3.0;
    case "semiannual": return 1.0 / 6.0;
    case "annual": return 1.0 / 12.0;
    case "custom": return 1;
  }
}

export const STATUSES = ["active", "trial", "paused", "cancelled"] as const;
export type SubscriptionStatus = (typeof STATUSES)[number];

export const statusLabel: Record<SubscriptionStatus, string> = {
  active: "Активна",
  trial: "Триал",
  paused: "Приостановлена",
  cancelled: "Отменена",
};

export interface Category {
  id: string;
  name: string;
  /// 0xRRGGBB, like the iOS app (stored as ARGB int in backups).
  colorHex: number;
  /// SF Symbol name (same strings the iOS app stores).
  symbol: string;
}

export interface Subscription {
  id: string;
  name: string;
  amount: number;
  currency: Currency;
  billingPeriod: BillingPeriod;
  customPeriodDays: number | null;
  categoryId: string | null;
  nextBillingDate: Date;
  reminderDaysBefore: number;
  status: SubscriptionStatus;
  /// When the free period ends (status "trial"); the first charge follows it.
  trialEndDate: Date | null;
  startDate: Date;
  note: string | null;
  /// Domain used to fetch a favicon.
  domain: string | null;
  createdAt: Date;
  /// Catalog icon name (kept for round-trip compatibility).
  icon: string | null;
}

export function logoURL(domain: string | null): string | null {
  return domain ? `https://www.google.com/s2/favicons?domain=${domain}&sz=128` : null;
}

export type PaymentKind = "charge" | "skip";
export type PaymentSource = "auto" | "manual" | "bank";

export interface PaymentRecord {
  /// `subscriptionId` + the charge's day: stable across re-planning and devices.
  id: string;
  subscriptionId: string;
  date: Date;
  amount: number;
  currency: Currency;
  /// RUB snapshot at recording time.
  amountRub: number;
  kind: PaymentKind;
  source: PaymentSource;
}

function pad(n: number, width: number): string {
  return String(n).padStart(width, "0");
}

export function ymd(date: Date): string {
  return `${pad(date.getFullYear(), 4)}-${pad(date.getMonth() + 1, 2)}-${pad(date.getDate(), 2)}`;
}

export function makePaymentId(subscriptionId: string, date: Date): string {
  return `${subscriptionId}-${ymd(date)}`;
}

// View-model types (PeriodTotal, CategoryShare, MonthDelta, AnnualCost, PaymentEvent).

export interface PaymentEvent {
  subscription: Subscription;
  date: Date;
  record: PaymentRecord | null;
}

export interface PeriodTotal {
  start: Date;
  amount: number;
  isForecast: boolean;
}

export interface CategoryShare {
  category: Category | null;
  paid: number;
  total: number;
}

export interface MonthDelta {
  current: number;
  previous: number;
  delta: number;
}

export interface AnnualCost {
  subscription: Subscription;
  perYearRub: number;
}
