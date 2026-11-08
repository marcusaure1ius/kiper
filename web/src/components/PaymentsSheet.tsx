"use client";

// PaymentsSheet.swift — all payments, two modes (history / upcoming),
// grouped by month, history rows with mark-paid / skip / delete.

import { useMemo, useState } from "react";
import { money, monthName, relative, rub, smartDate } from "@/lib/format";
import { makePaymentId, PaymentEvent } from "@/lib/models";
import { futurePayments, pastPayments, toRub, useKiper } from "@/lib/store";
import { useUI } from "@/lib/ui";
import { Sheet, Segmented } from "./ui";
import { SubscriptionLogo } from "./SubscriptionViews";
import { Sym } from "./Sym";

export function PaymentsSheet() {
  const open = useUI((s) => s.paymentsOpen);
  const close = useUI((s) => s.closePayments);
  const tab = useUI((s) => s.paymentsTab);
  const setTab = useUI((s) => s.openPayments);

  const subs = useKiper((s) => s.subscriptions);
  const categories = useKiper((s) => s.categories);
  const payments = useKiper((s) => s.payments);
  const rate = useKiper((s) => s.rateSnapshot);
  const markPaid = useKiper((s) => s.markPaid);
  const skip = useKiper((s) => s.skip);
  const deletePayment = useKiper((s) => s.deletePayment);
  const show = useKiper((s) => s.show);

  const history = useMemo(
    () => (open ? pastPayments({ subscriptions: subs, payments, rateSnapshot: rate }, 365) : []),
    [open, subs, payments, rate],
  );
  const upcoming = useMemo(() => (open ? futurePayments({ subscriptions: subs }, 90) : []), [open, subs]);

  const rows = tab === "history" ? history : upcoming;
  const groups = useMemo(() => {
    const map = new Map<string, PaymentEvent[]>();
    for (const e of rows) {
      const key = `${e.date.getFullYear()}-${e.date.getMonth()}`;
      const list = map.get(key) ?? [];
      list.push(e);
      map.set(key, list);
    }
    return [...map.entries()].map(([key, events]) => {
      const [y, m] = key.split("-").map(Number);
      const label = monthName(new Date(y, m, 1));
      const total = events.reduce((sum, e) => sum + (e.record && e.record.kind === "skip" ? 0 : toRub(e.subscription.amount, e.subscription.currency, { rateSnapshot: rate })), 0);
      return { key, label, events, total };
    });
  }, [rows, rate]);

  return (
    <Sheet open={open} onClose={close} title="Платежи" detent="full">
      <div style={{ position: "sticky", top: 0, zIndex: 5, background: "linear-gradient(to bottom, color-mix(in srgb, var(--mat-bg-strong) 92%, transparent), transparent)", paddingBottom: 12 }}>
        <Segmented
          options={[
            { value: "history", label: "История" },
            { value: "upcoming", label: "Предстоящие" },
          ]}
          value={tab}
          onChange={(v) => setTab(v)}
        />
      </div>
      {rows.length === 0 && (
        <div className="t-subheadline secondary" style={{ textAlign: "center", padding: "40px 0" }}>
          {tab === "history" ? "Пока нет платежей" : "Предстоящих списаний нет"}
        </div>
      )}
      {groups.map((g) => (
        <div key={g.key} style={{ marginBottom: 18 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", padding: "4px 4px 8px" }}>
            <div className="t-subheadline secondary" style={{ fontWeight: 600 }}>
              {tab === "history" ? `${g.label} ${g.events[0].date.getFullYear()} ` : g.label}
            </div>
            <div className="t-subheadline secondary num">{rub(g.total)}</div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {g.events.map((e) => (
              <PaymentRow
                key={`${e.subscription.id}-${e.date.getTime()}`}
                event={e}
                category={categories.find((c) => c.id === e.subscription.categoryId) ?? null}
                skipped={e.record?.kind === "skip"}
                rate={rate}
                onPay={() => {
                  markPaid(e.subscription, e.date);
                  show("Отмечено оплаченным");
                }}
                onSkip={() => {
                  skip(e.subscription, e.date);
                  show("Списание пропущено", "pause.circle.fill", "orange");
                }}
                onDelete={() => {
                  if (e.record) deletePayment(e.record.id);
                }}
              />
            ))}
          </div>
        </div>
      ))}
    </Sheet>
  );
}

function PaymentRow({
  event,
  category,
  skipped,
  rate,
  onPay,
  onSkip,
  onDelete,
}: {
  event: PaymentEvent;
  category: ReturnType<typeof useKiper.getState>["categories"][number] | null;
  skipped: boolean;
  rate: { usd: number; eur: number; fetchedAt: Date };
  onPay: () => void;
  onSkip: () => void;
  onDelete: () => void;
}) {
  const sub = event.subscription;
  const isHistory = event.record != null;
  return (
    <div className="row-card" style={{ display: "flex", alignItems: "center", gap: 14, padding: 14, opacity: skipped ? 0.55 : 1 }}>
      <SubscriptionLogo size={44} category={category} domain={sub.domain} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="t-body" style={{ fontWeight: 500, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {sub.name}
        </div>
        <div className="t-subheadline secondary">
          {isHistory ? smartDate(event.date) : relative(event.date)}
          {skipped && " · Пропущено"}
        </div>
      </div>
      <div className="num" style={{ fontWeight: 600, flex: "none" }}>
        {money(event.record?.amount ?? sub.amount, event.record?.currency ?? sub.currency)}
      </div>
      {isHistory ? (
        <div style={{ display: "flex", gap: 6, flex: "none" }}>
          <ActionBtn label="Оплачено" tint="#34c759" onClick={onPay} symbol="checkmark.circle.fill" />
          <ActionBtn label="Пропустить" tint="#ff9f0a" onClick={onSkip} symbol="pause.circle.fill" />
          <ActionBtn label="Удалить" tint="#ff453a" onClick={onDelete} symbol="trash" />
        </div>
      ) : null}
    </div>
  );
}

function ActionBtn({ label, tint, onClick, symbol }: { label: string; tint: string; onClick: () => void; symbol: string }) {
  return (
    <button
      onClick={onClick}
      aria-label={label}
      title={label}
      style={{ color: tint, display: "flex", alignItems: "center", padding: 4 }}
    >
      <Sym name={symbol} size={20} />
    </button>
  );
}
