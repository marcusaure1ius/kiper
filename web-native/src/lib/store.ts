// Port of ios-native/Kiper/Data/AppStore.swift — app state, mutations,
// persistence (localStorage holds the same BackupFile v1 JSON as exports),
// CBR rate refresh, and every derived calculation used by the UI.

import { create } from "zustand";
import {
  BackupError, BackupFileV1, backupDateString, categoryFromDTO, categoryToDTO, decodeBackup,
  decodeCSV, encodeBackup, makeBackupFile, paymentFromDTO, paymentToDTO, subscriptionFromDTO,
  subscriptionToDTO,
} from "./backup";
import { endOfMonth, startOfMonth, startOfWeekISO, daysBetweenSafe } from "./intervals";
import { seedCategories } from "./catalog";
import { startOfDay } from "./date";
import {
  AnnualCost, Category, CategoryShare, Currency, CURRENCIES, MonthDelta, PaymentEvent,
  PaymentKind, PaymentRecord, PaymentSource, PeriodTotal, Subscription, makePaymentId, monthlyEquivalent,
} from "./models";
import { firstCharge, scheduleDates } from "./schedule";

export interface RateSnapshot {
  usd: number;
  eur: number;
  fetchedAt: Date;
}

export const RATES_MAX_AGE_MS = 6 * 60 * 60 * 1000; // ExchangeRates.maxAge
const RATES_FALLBACK: RateSnapshot = { usd: 90, eur: 98, fetchedAt: new Date(0) };

export const BUDGET_KEY = "budgetRub"; // key inside BackupFile.settings
const DATA_KEY = "kiper.data.v1";
const RATES_KEY = "kiper.rates.v1";
const QUARANTINE_KEY = "kiper.quarantine.v1";

export type ToastTint = "green" | "orange" | "red";

export interface Toast {
  id: number;
  text: string;
  symbol: string;
  tint: ToastTint;
}

export interface ImportResult {
  subscriptions: number;
  categories: number;
  skipped: number;
}

interface KiperState {
  hydrated: boolean;
  subscriptions: Subscription[];
  categories: Category[];
  payments: PaymentRecord[];
  rateSnapshot: RateSnapshot;
  refreshingRates: boolean;
  loadError: string | null;
  monthlyBudgetRub: number | null;
  toast: Toast | null;

  hydrate: () => void;
  upsert: (sub: Subscription) => void;
  togglePause: (id: string) => void;
  endTrial: (id: string) => void;
  cancel: (id: string) => void;
  upsertCategory: (cat: Category) => void;
  deleteCategory: (id: string) => void;
  markPaid: (sub: Subscription, date: Date) => void;
  skip: (sub: Subscription, date: Date) => void;
  deletePayment: (id: string) => void;
  setBudget: (rub: number | null) => void;
  refreshRates: (silent?: boolean) => Promise<void>;
  importBackup: (file: BackupFileV1, mode: "replace" | "merge") => ImportResult;
  importCSV: (text: string) => ImportResult;
  resetAll: () => void;
  show: (text: string, symbol?: string, tint?: ToastTint) => void;
  dismissToast: () => void;
  loadDemoData: () => void;
}

// MARK: - Storage

function readRaw(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeRaw(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // Storage full / private mode — keep running in memory.
  }
}

function saveRates(snapshot: RateSnapshot): void {
  writeRaw(RATES_KEY, JSON.stringify({ usd: snapshot.usd, eur: snapshot.eur, fetchedAt: snapshot.fetchedAt.toISOString() }));
}

function loadRates(): RateSnapshot {
  const raw = readRaw(RATES_KEY);
  if (!raw) return RATES_FALLBACK;
  try {
    const parsed = JSON.parse(raw) as { usd: number; eur: number; fetchedAt: string };
    return { usd: parsed.usd, eur: parsed.eur, fetchedAt: new Date(parsed.fetchedAt) };
  } catch {
    return RATES_FALLBACK;
  }
}

let saveTimer: ReturnType<typeof setTimeout> | null = null;

function scheduleSave(get: () => KiperState): void {
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    saveTimer = null;
    const s = get();
    writeRaw(DATA_KEY, encodeBackup(currentBackup(s)));
  }, 250);
}

function currentBackup(s: KiperState, now: Date = new Date()): BackupFileV1 {
  const settings: Record<string, string> = {};
  if (s.monthlyBudgetRub != null) settings[BUDGET_KEY] = String(s.monthlyBudgetRub);
  return makeBackupFile(
    { subscriptions: s.subscriptions, categories: s.categories, settings, payments: s.payments },
    now,
  );
}

// MARK: - Store

export const useKiper = create<KiperState>((set, get) => {
  const changed = () => scheduleSave(get);

  function recordPayment(
    subs: Subscription[],
    payments: PaymentRecord[],
    sub: Subscription,
    date: Date,
    kind: PaymentKind,
    source: PaymentSource,
    toRub: (amount: number, currency: Currency) => number,
  ): PaymentRecord[] {
    const record: PaymentRecord = {
      id: makePaymentId(sub.id, date),
      subscriptionId: sub.id,
      date,
      amount: sub.amount,
      currency: sub.currency,
      amountRub: toRub(sub.amount, sub.currency),
      kind,
      source,
    };
    const i = payments.findIndex((p) => p.id === record.id);
    if (i >= 0) {
      if (source === "manual" || payments[i].source === "auto") {
        const next = payments.slice();
        next[i] = record;
        return next;
      }
      return payments;
    }
    return [...payments, record];
  }

  /// Rolls past nextBillingDates forward; ended trials become active. Mirrors
  /// AppStore.advanceBillingDates.
  function advanceBillingDates(now: Date = new Date()): void {
    const today = startOfDay(now);
    let changedData = false;
    const subs = get().subscriptions.map((sub) => ({ ...sub }));
    let payments = get().payments;
    const rate = get().rateSnapshot;
    const toRub = (amount: number, currency: Currency) => amount * rateFor(currency, rate);

    for (const sub of subs) {
      if (sub.status === "trial" && sub.trialEndDate && startOfDay(sub.trialEndDate) < today) {
        sub.status = "active";
        sub.trialEndDate = null;
        sub.startDate = sub.nextBillingDate;
        changedData = true;
      }
    }
    for (const sub of subs) {
      if (sub.status !== "active") continue;
      if (!(startOfDay(sub.nextBillingDate) < today)) continue;
      for (const date of scheduleDates(sub, sub.nextBillingDate, today, now)) {
        payments = recordPayment(subs, payments, sub, date, "charge", "auto", toRub);
      }
      const next = firstCharge(sub, today);
      if (next.getTime() !== sub.nextBillingDate.getTime()) {
        sub.nextBillingDate = next;
        changedData = true;
      }
    }
    if (changedData || payments !== get().payments) {
      set({ subscriptions: subs, payments });
      changed();
    }
  }

  return {
    hydrated: false,
    subscriptions: [],
    categories: [],
    payments: [],
    rateSnapshot: RATES_FALLBACK,
    refreshingRates: false,
    loadError: null,
    monthlyBudgetRub: null,
    toast: null,

    hydrate: () => {
      if (get().hydrated || typeof window === "undefined") return;
      const rateSnapshot = loadRates();
      const raw = readRaw(DATA_KEY);
      let state: Partial<KiperState> = { hydrated: true, rateSnapshot };
      if (raw == null) {
        // First launch: seed categories, like the production iOS app.
        state = { ...state, categories: seedCategories(), subscriptions: [], payments: [] };
        set(state as KiperState);
        changed();
      } else {
        try {
          const file = decodeBackup(raw);
          const categories = file.categories.map(categoryFromDTO);
          const subscriptions: Subscription[] = [];
          for (const dto of file.subscriptions) {
            const sub = subscriptionFromDTO(dto);
            if (sub) subscriptions.push(sub);
          }
          const payments = (file.payments ?? []).map(paymentFromDTO).filter((p): p is PaymentRecord => p != null);
          const budgetRaw = file.settings[BUDGET_KEY];
          state = {
            ...state,
            categories,
            subscriptions,
            payments,
            monthlyBudgetRub: budgetRaw != null && budgetRaw !== "" && !Number.isNaN(Number(budgetRaw)) ? Number(budgetRaw) : null,
          };
          set(state as KiperState);
        } catch (error) {
          const reason = error instanceof BackupError ? error.message : "Не удалось прочитать сохранённые данные.";
          writeRaw(QUARANTINE_KEY, raw);
          state = { ...state, categories: seedCategories(), subscriptions: [], payments: [], loadError: reason };
          set(state as KiperState);
        }
      }
      advanceBillingDates();
      const snap = get().rateSnapshot;
      if (Date.now() - snap.fetchedAt.getTime() > RATES_MAX_AGE_MS) void get().refreshRates(true);
    },

    upsert: (sub) => {
      const subs = get().subscriptions.slice();
      const i = subs.findIndex((s) => s.id === sub.id);
      if (i >= 0) subs[i] = sub;
      else subs.push(sub);
      set({ subscriptions: subs });
      advanceBillingDates();
      changed();
    },

    togglePause: (id) => {
      const subs = get().subscriptions.slice();
      const i = subs.findIndex((s) => s.id === id);
      if (i < 0 || (subs[i].status !== "active" && subs[i].status !== "paused")) return;
      subs[i] = { ...subs[i], status: subs[i].status === "paused" ? "active" : "paused" };
      set({ subscriptions: subs });
      advanceBillingDates();
      changed();
    },

    endTrial: (id) => {
      const subs = get().subscriptions.slice();
      const i = subs.findIndex((s) => s.id === id);
      if (i < 0 || subs[i].status !== "trial") return;
      subs[i] = { ...subs[i], status: "active", trialEndDate: null, startDate: subs[i].nextBillingDate };
      set({ subscriptions: subs });
      advanceBillingDates();
      changed();
    },

    cancel: (id) => {
      const subs = get().subscriptions.slice();
      const i = subs.findIndex((s) => s.id === id);
      if (i < 0) return;
      subs[i] = { ...subs[i], status: "cancelled" };
      set({ subscriptions: subs });
      changed();
    },

    upsertCategory: (cat) => {
      const categories = get().categories.slice();
      const i = categories.findIndex((c) => c.id === cat.id);
      if (i >= 0) categories[i] = cat;
      else categories.push(cat);
      set({ categories });
      changed();
    },

    deleteCategory: (id) => {
      const subscriptions = get().subscriptions.map((s) => (s.categoryId === id ? { ...s, categoryId: null } : s));
      const categories = get().categories.filter((c) => c.id !== id);
      set({ subscriptions, categories });
      changed();
    },

    markPaid: (sub, date) => {
      const rate = get().rateSnapshot;
      const payments = recordPayment(
        get().subscriptions, get().payments, sub, date, "charge", "manual",
        (amount, currency) => amount * rateFor(currency, rate),
      );
      set({ payments });
      changed();
    },

    skip: (sub, date) => {
      const rate = get().rateSnapshot;
      const payments = recordPayment(
        get().subscriptions, get().payments, sub, date, "skip", "manual",
        (amount, currency) => amount * rateFor(currency, rate),
      );
      set({ payments });
      changed();
    },

    deletePayment: (id) => {
      set({ payments: get().payments.filter((p) => p.id !== id) });
      changed();
    },

    setBudget: (rub) => {
      set({ monthlyBudgetRub: rub });
      changed();
    },

    refreshRates: async (silent = false) => {
      if (get().refreshingRates) return;
      set({ refreshingRates: true });
      try {
        const res = await fetch("/api/rates");
        if (!res.ok) throw new Error(String(res.status));
        const data = (await res.json()) as { usd: number; eur: number };
        const snapshot: RateSnapshot = { usd: data.usd, eur: data.eur, fetchedAt: new Date() };
        set({ rateSnapshot: snapshot, refreshingRates: false });
        saveRates(snapshot);
        if (!silent) get().show("Курсы обновлены");
      } catch {
        set({ refreshingRates: false });
        if (!silent) get().show("Нет связи с ЦБ — используются сохранённые курсы", "wifi.exclamationmark", "orange");
      }
    },

    importBackup: (file, mode) => {
      const cats = file.categories.map(categoryFromDTO);
      const subs: Subscription[] = [];
      let skipped = 0;
      for (const dto of file.subscriptions) {
        const sub = subscriptionFromDTO(dto);
        if (sub) subs.push(sub);
        else skipped += 1;
      }
      const pays = (file.payments ?? []).map(paymentFromDTO).filter((p): p is PaymentRecord => p != null);

      if (mode === "replace") {
        set({ categories: cats, subscriptions: subs, payments: pays, loadError: null });
      } else {
        const categories = get().categories.slice();
        for (const c of cats) {
          const i = categories.findIndex((x) => x.id === c.id);
          if (i >= 0) categories[i] = c;
          else categories.push(c);
        }
        const subscriptions = get().subscriptions.slice();
        for (const s of subs) {
          const i = subscriptions.findIndex((x) => x.id === s.id);
          if (i >= 0) subscriptions[i] = s;
          else subscriptions.push(s);
        }
        const payments = get().payments.slice();
        for (const p of pays) {
          const i = payments.findIndex((x) => x.id === p.id);
          if (i >= 0) payments[i] = p;
          else payments.push(p);
        }
        set({ categories, subscriptions, payments });
      }
      // Drop dangling category links (a category may be missing from the file).
      const known = new Set(get().categories.map((c) => c.id));
      set({
        subscriptions: get().subscriptions.map((s) =>
          s.categoryId && !known.has(s.categoryId) ? { ...s, categoryId: null } : s,
        ),
      });
      const budgetRaw = file.settings[BUDGET_KEY];
      if (budgetRaw != null && !Number.isNaN(Number(budgetRaw))) set({ monthlyBudgetRub: Number(budgetRaw) });
      advanceBillingDates();
      changed();
      return { subscriptions: subs.length, categories: cats.length, skipped };
    },

    importCSV: (text) => {
      // CSV carries subscriptions only; keep icon/domain/createdAt from existing rows.
      const rows = decodeCSV(text).map((row) => {
        const old = get().subscriptions.find((s) => s.id === row.id);
        return old ? { ...row, icon: old.icon, domain: old.domain ?? row.domain, createdAt: old.createdAt } : row;
      });
      const file = makeBackupFile({ subscriptions: rows, categories: [], payments: [] }, new Date(0));
      return get().importBackup({ ...file, exportedAt: "" }, "merge");
    },

    resetAll: () => {
      set({ subscriptions: [], categories: seedCategories(), payments: [], monthlyBudgetRub: null, loadError: null });
      changed();
    },

    show: (text, symbol = "checkmark.circle.fill", tint = "green") => {
      set({ toast: { id: Date.now(), text, symbol, tint } });
    },

    dismissToast: () => set({ toast: null }),

    loadDemoData: () => {
      if (process.env.NODE_ENV === "production") return;
      void import("./demo").then(({ demoFile }) => {
        get().importBackup(demoFile, "replace");
      });
    },
  };
});

// MARK: - Rates

export function rateFor(currency: Currency, snapshot: RateSnapshot): number {
  switch (currency) {
    case "RUB": return 1;
    case "USD": return snapshot.usd;
    case "EUR": return snapshot.eur;
  }
}

export function ratesOf(snapshot: RateSnapshot): Record<Currency, number> {
  return { RUB: 1, USD: snapshot.usd, EUR: snapshot.eur };
}

// MARK: - Filters

export const activeSubs = (s: Pick<KiperState, "subscriptions">) => s.subscriptions.filter((x) => x.status === "active");
export const notCancelled = (s: Pick<KiperState, "subscriptions">) => s.subscriptions.filter((x) => x.status !== "cancelled");
/// Trials don't generate charge history yet, so analytics skips them.
export const chargeable = (s: Pick<KiperState, "subscriptions">) =>
  s.subscriptions.filter((x) => x.status !== "cancelled" && x.status !== "trial");

export function categoryOf(s: KiperState, id: string | null): Category | null {
  return id ? (s.categories.find((c) => c.id === id) ?? null) : null;
}

export function toRub(amount: number, currency: Currency, s: Pick<KiperState, "rateSnapshot">): number {
  return amount * rateFor(currency, s.rateSnapshot);
}

// MARK: - Home

export function monthlyTotalRub(s: Pick<KiperState, "subscriptions" | "rateSnapshot">): number {
  return activeSubs(s).reduce((sum, sub) => sum + toRub(sub.amount, sub.currency, s) * monthlyEquivalent(sub.billingPeriod), 0);
}

export function monthProgress(s: Pick<KiperState, "subscriptions" | "payments" | "rateSnapshot">, now: Date = new Date()): { paid: number; remaining: number } {
  const today = startOfDay(now);
  const month = startOfMonth(now);
  const monthEnd = endOfMonth(now);
  let paid = 0;
  let remaining = 0;
  const recordedRub = (sub: Subscription, date: Date): number => {
    const id = makePaymentId(sub.id, date);
    const r = s.payments.find((p) => p.id === id);
    if (!r) return toRub(sub.amount, sub.currency, s);
    return r.kind === "skip" ? 0 : r.amountRub;
  };
  for (const sub of activeSubs(s)) {
    for (const date of scheduleDates(sub, month, monthEnd, now)) {
      const r = recordedRub(sub, date);
      if (date < today) paid += r;
      else remaining += r;
    }
  }
  // A trial's first charge is already scheduled — count it as remaining.
  for (const sub of s.subscriptions) {
    if (sub.status !== "trial") continue;
    for (const _ of scheduleDates(sub, today, monthEnd, now)) remaining += toRub(sub.amount, sub.currency, s);
  }
  return { paid, remaining };
}

/// Past charges: recorded payments first (real amounts), then schedule inference.
export function pastPayments(s: Pick<KiperState, "subscriptions" | "payments" | "rateSnapshot">, days = 90, now: Date = new Date()): PaymentEvent[] {
  const today = startOfDay(now);
  const start = new Date(today);
  start.setDate(start.getDate() - days);
  const events: PaymentEvent[] = [];
  const covered = new Set<string>();
  for (const r of s.payments) {
    if (r.kind !== "charge" || r.date < start || r.date >= today) continue;
    const sub = s.subscriptions.find((x) => x.id === r.subscriptionId);
    if (!sub) continue;
    events.push({ subscription: sub, date: r.date, record: r });
    covered.add(r.id);
  }
  for (const sub of activeSubs(s)) {
    for (const date of scheduleDates(sub, start, today, now)) {
      const id = makePaymentId(sub.id, date);
      if (!covered.has(id)) events.push({ subscription: sub, date, record: null });
    }
  }
  return events.sort((a, b) => b.date.getTime() - a.date.getTime());
}

export function futurePayments(s: Pick<KiperState, "subscriptions">, days = 90, now: Date = new Date()): PaymentEvent[] {
  const today = startOfDay(now);
  const end = new Date(today);
  end.setDate(end.getDate() + days);
  const pool = [...activeSubs(s), ...s.subscriptions.filter((x) => x.status === "trial")];
  return pool
    .flatMap((sub) => scheduleDates(sub, today, end, now).map((date) => ({ subscription: sub, date, record: null })))
    .sort((a, b) => a.date.getTime() - b.date.getTime());
}

// MARK: - Analytics

export function monthlyTotals(s: Pick<KiperState, "subscriptions" | "payments" | "rateSnapshot">, past = 6, future = 3, now: Date = new Date()): PeriodTotal[] {
  const current = startOfMonth(now);
  const starts: Date[] = [];
  for (let i = -past; i <= future; i++) starts.push(startOfMonth(new Date(current.getFullYear(), current.getMonth() + i, 1)));
  const end = endOfMonth(starts[starts.length - 1]);
  return totalsFor(s, starts, end, current, now, (d) => startOfMonth(d));
}

export function weeklyTotals(s: Pick<KiperState, "subscriptions" | "payments" | "rateSnapshot">, past = 6, future = 4, now: Date = new Date()): PeriodTotal[] {
  const current = startOfWeekISO(now);
  const starts: Date[] = [];
  for (let i = -past; i <= future; i++) starts.push(startOfWeekISO(new Date(current.getFullYear(), current.getMonth(), current.getDate() + 7 * i)));
  const end = startOfWeekISO(new Date(starts[starts.length - 1].getFullYear(), starts[starts.length - 1].getMonth(), starts[starts.length - 1].getDate() + 7));
  return totalsFor(s, starts, end, current, now, (d) => startOfWeekISO(d));
}

function totalsFor(
  s: Pick<KiperState, "subscriptions" | "payments" | "rateSnapshot">,
  buckets: Date[],
  end: Date,
  current: Date,
  now: Date,
  bucketOf: (d: Date) => Date,
): PeriodTotal[] {
  const sums = new Map<string, number>();
  for (const sub of chargeable(s)) {
    for (const date of scheduleDates(sub, buckets[0], end, now)) {
      const key = bucketOf(date).getTime().toString();
      const id = makePaymentId(sub.id, date);
      const r = s.payments.find((p) => p.id === id);
      const rub = r ? (r.kind === "skip" ? 0 : r.amountRub) : toRub(sub.amount, sub.currency, s);
      sums.set(key, (sums.get(key) ?? 0) + rub);
    }
  }
  return buckets.map((start) => ({
    start,
    amount: sums.get(start.getTime().toString()) ?? 0,
    isForecast: start >= current,
  }));
}

/// Per-category charges inside the month interval (RUB), paid vs total.
export function categoryShares(s: Pick<KiperState, "subscriptions" | "payments" | "rateSnapshot" | "categories">, from: Date, to: Date, now: Date = new Date()): CategoryShare[] {
  const today = startOfDay(now);
  const paid = new Map<string, number>();
  const total = new Map<string, number>();
  const bump = (map: Map<string, number>, key: string, value: number) => map.set(key, (map.get(key) ?? 0) + value);
  for (const sub of chargeable(s)) {
    for (const date of scheduleDates(sub, from, to, now)) {
      const key = sub.categoryId ?? "none";
      const id = makePaymentId(sub.id, date);
      const r = s.payments.find((p) => p.id === id);
      const rub = r ? (r.kind === "skip" ? 0 : r.amountRub) : toRub(sub.amount, sub.currency, s);
      bump(total, key, rub);
      if (date < today) bump(paid, key, rub);
    }
  }
  return [...total.entries()]
    .map(([key, t]) => ({
      category: key === "none" ? null : (s.categories.find((c) => c.id === key) ?? null),
      paid: paid.get(key) ?? 0,
      total: t,
    }))
    .sort((a, b) => b.total - a.total);
}

/// Same-span comparison: charges since this month's start vs the same span of
/// the previous month (fair while the month is still running).
export function monthOverMonth(s: Pick<KiperState, "subscriptions" | "payments" | "rateSnapshot">, now: Date = new Date()): MonthDelta | null {
  const month = startOfMonth(now);
  const prevMonth = startOfMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1));
  const today = startOfDay(now);
  const current = chargesTotal(s, month, today, now);
  const previous = chargesTotal(s, prevMonth, daysBetweenSafe(prevMonth, today, month), now);
  if (current <= 0 && previous <= 0) return null;
  return { current, previous, delta: current - previous };
}

function chargesTotal(s: Pick<KiperState, "subscriptions" | "payments" | "rateSnapshot">, from: Date, to: Date, now: Date): number {
  let sum = 0;
  for (const sub of chargeable(s)) {
    for (const date of scheduleDates(sub, from, to, now)) {
      const id = makePaymentId(sub.id, date);
      const r = s.payments.find((p) => p.id === id);
      sum += r ? (r.kind === "skip" ? 0 : r.amountRub) : toRub(sub.amount, sub.currency, s);
    }
  }
  return sum;
}

/// Steady-state year cost: active spending projected over 12 months.
export function annualForecast(s: Pick<KiperState, "subscriptions" | "rateSnapshot">): { totalRub: number; top: AnnualCost[] } {
  const items = activeSubs(s)
    .map((subscription) => ({
      subscription,
      perYearRub: toRub(subscription.amount, subscription.currency, s) * monthlyEquivalent(subscription.billingPeriod) * 12,
    }))
    .sort((a, b) => b.perYearRub - a.perYearRub);
  return { totalRub: items.reduce((sum, item) => sum + item.perYearRub, 0), top: items.slice(0, 3) };
}

function normalizeName(name: string): string {
  return name
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .trim();
}

/// Likely duplicates: same service domain, or same category with one name
/// containing the other ("Netflix" vs "Netflix Premium"). A hint, not a verdict.
export function duplicateGroups(s: Pick<KiperState, "subscriptions">): Subscription[][] {
  const pool = notCancelled(s);
  const groups: Subscription[][] = [];
  const byDomain = new Map<string, Subscription[]>();
  for (const sub of pool) {
    const domain = sub.domain?.toLowerCase();
    if (domain) byDomain.set(domain, [...(byDomain.get(domain) ?? []), sub]);
  }
  groups.push(...[...byDomain.values()].filter((g) => g.length > 1));
  const used = new Set(groups.flat().map((x) => x.id));

  const byCategory = new Map<string, Subscription[]>();
  for (const sub of pool) {
    const key = sub.categoryId ?? "none";
    byCategory.set(key, [...(byCategory.get(key) ?? []), sub]);
  }
  for (const peers of byCategory.values()) {
    for (const seed of peers) {
      if (used.has(seed.id)) continue;
      const a = normalizeName(seed.name);
      const matches = peers.filter((other) => {
        if (other.id === seed.id || used.has(other.id)) return false;
        const b = normalizeName(other.name);
        if (Math.min(a.length, b.length) < 3) return false;
        return a.includes(b) || b.includes(a);
      });
      if (matches.length === 0) continue;
      const group = [seed, ...matches];
      groups.push(group);
      for (const g of group) used.add(g.id);
    }
  }
  return groups;
}

// MARK: - Export helpers

export function backupOf(s: KiperState, now: Date = new Date()): BackupFileV1 {
  return currentBackup(s, now);
}

export function exportJSON(s: KiperState): string {
  return encodeBackup(backupOf(s));
}

/// The last charge that actually happened, if any (recorded amounts only).
export function lastCharge(s: Pick<KiperState, "payments">, subId: string): PaymentRecord | null {
  let best: PaymentRecord | null = null;
  for (const p of s.payments) {
    if (p.subscriptionId === subId && p.kind === "charge" && (!best || p.date > best.date)) best = p;
  }
  return best;
}

export function paymentDTOs(payments: PaymentRecord[]) {
  return payments.map(paymentToDTO);
}

export function categoryDTO(c: Category) {
  return categoryToDTO(c);
}

export function subscriptionDTO(s: Subscription) {
  return subscriptionToDTO(s);
}

export { BackupError, backupDateString };
