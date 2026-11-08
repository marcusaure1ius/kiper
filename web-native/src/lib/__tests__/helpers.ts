// Shared fixtures for the lib tests, mirroring KiperTests/Helpers.swift.

import { Currency, makePaymentId, PaymentRecord, Subscription } from "@/lib/models";

export function makeSub(overrides: Partial<Subscription> = {}): Subscription {
  return {
    id: "sub-1",
    name: "Подписка",
    amount: 500,
    currency: "RUB",
    billingPeriod: "monthly",
    customPeriodDays: null,
    categoryId: null,
    nextBillingDate: new Date(2026, 11, 5),
    reminderDaysBefore: 1,
    status: "active",
    trialEndDate: null,
    startDate: new Date(2026, 0, 5),
    note: null,
    domain: null,
    createdAt: new Date(2026, 0, 5),
    icon: null,
    ...overrides,
  };
}

export const rates = { usd: 90, eur: 98, fetchedAt: new Date(0) };

export function makePayment(
  subscriptionId: string,
  date: Date,
  overrides: Partial<PaymentRecord> = {},
): PaymentRecord {
  return {
    id: makePaymentId(subscriptionId, date),
    subscriptionId,
    date,
    amount: 500,
    currency: "RUB" as Currency,
    amountRub: 500,
    kind: "charge",
    source: "auto",
    ...overrides,
  };
}
