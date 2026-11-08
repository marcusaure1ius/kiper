"use client";

// HomeScreen.swift — month summary hero card, Подписки/Добавить buttons,
// «Ближайшие списания» card.

import Link from "next/link";
import { useMemo } from "react";
import { CalendarBlank, CheckCircle, Clock, ListBullets, Plus, Target, Tray } from "@phosphor-icons/react";
import { money, monthName, relative, rub, smartDate } from "@/lib/format";
import { futurePayments, monthProgress, monthlyTotalRub, useKiper } from "@/lib/store";
import { startOfDay } from "@/lib/date";
import { Category } from "@/lib/models";
import { SubscriptionLogo, SubscriptionRow } from "@/components/SubscriptionViews";
import { EmptyState, useCountUp } from "@/components/ui";
import { useUI } from "@/lib/ui";

export default function HomePage() {
  const openPayments = useUI((s) => s.openPayments);
  const openAdd = useUI((s) => s.openAdd);

  return (
    <div className="page home-pad" style={{ paddingTop: 8 }}>
      <div className="nav-bar" style={{ padding: "10px 4px 14px", position: "static" }}>
        <h1 className="t-largeTitle" style={{ margin: 0 }}>
          Кипер
        </h1>
        <button
          onClick={() => openPayments()}
          className="glass tap-scale"
          aria-label="Все платежи"
          style={{ width: 38, height: 38, borderRadius: 19, display: "flex", alignItems: "center", justifyContent: "center" }}
        >
          <CalendarBlank size={19} />
        </button>
      </div>

      <div className="home-grid">
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <MonthSummaryCard />
          <div style={{ display: "flex", gap: 12 }}>
            <Link href="/subscriptions" className="btn-glass" style={{ flex: 1 }}>
              <ListBullets size={18} />
              Подписки
            </Link>
            <button className="btn-prominent" style={{ flex: 1 }} onClick={() => openAdd()}>
              <Plus size={18} weight="bold" />
              Добавить
            </button>
          </div>
        </div>
        <UpcomingCard onAdd={() => openAdd()} />
      </div>
    </div>
  );
}

function MonthSummaryCard() {
  const budget = useKiper((s) => s.monthlyBudgetRub);
  const hydrated = useKiper((s) => s.hydrated);
  const subs = useKiper((s) => s.subscriptions);
  const payments = useKiper((s) => s.payments);
  const rate = useKiper((s) => s.rateSnapshot);
  const total = useMemo(
    () => (hydrated ? monthlyTotalRub({ subscriptions: subs, rateSnapshot: rate }) : 0),
    [hydrated, subs, rate],
  );
  const progress = useMemo(
    () => (hydrated ? monthProgress({ subscriptions: subs, payments, rateSnapshot: rate }) : { paid: 0, remaining: 0 }),
    [hydrated, subs, payments, rate],
  );
  const counted = useCountUp(total);
  const monthTotal = progress.paid + progress.remaining;
  const fraction = monthTotal > 0 ? Math.min(1, progress.paid / monthTotal) : 0;
  const over = budget != null && total > budget;

  return (
    <div className="hero-card" style={{ background: "color-mix(in srgb, var(--accent) 10%, var(--glass-bg))" }}>
      <div className="sheen" />
      <div className="t-subheadline secondary" style={{ fontWeight: 500 }}>
        {monthName(new Date())}
      </div>
      <div className="rounded-num num" style={{ fontSize: 44, fontWeight: 700, lineHeight: 1.15, margin: "2px 0 12px" }}>
        {rub(counted)}
      </div>
      <div className="progress" role="progressbar" aria-valuenow={Math.round(fraction * 100)}>
        <div style={{ width: `${fraction * 100}%` }} className={over ? "over" : ""} />
      </div>
      <div style={{ display: "flex", gap: 24, marginTop: 14 }}>
        <Stat icon={<CheckCircle size={13} weight="fill" />} tint="#34c759" label="Оплачено" value={rub(progress.paid)} />
        <Stat icon={<Clock size={13} weight="fill" />} tint="var(--accent)" label="Осталось" value={rub(progress.remaining)} />
      </div>
      {budget != null && (
        <div style={{ display: "flex", alignItems: "center", marginTop: 12, gap: 6 }}>
          <span style={{ color: over ? "#ff9f0a" : "var(--accent)", display: "flex" }}>
            {over ? <Target size={13} weight="fill" /> : <Target size={13} />}
          </span>
          <span className="t-caption secondary" style={{ fontWeight: 500 }}>
            Бюджет · {rub(budget)}
          </span>
          {over && (
            <span className="t-caption num" style={{ marginLeft: "auto", color: "#ff9f0a", fontWeight: 600 }}>
              перерасход {rub(total - budget)}
            </span>
          )}
        </div>
      )}
    </div>
  );
}

function Stat({ icon, tint, label, value }: { icon: React.ReactNode; tint: string; label: string; value: string }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
      <span style={{ color: tint, display: "flex" }}>{icon}</span>
      <div>
        <div className="t-caption secondary">{label}</div>
        <div className="t-subheadline num" style={{ fontWeight: 600 }}>
          {value}
        </div>
      </div>
    </div>
  );
}

function UpcomingCard({ onAdd }: { onAdd: () => void }) {
  const subs = useKiper((s) => s.subscriptions);
  const categories = useKiper((s) => s.categories);
  const rate = useKiper((s) => s.rateSnapshot);

  const events = useMemo(() => futurePayments({ subscriptions: subs }, 30).slice(0, 6), [subs]);
  const hasAny = subs.length > 0;

  return (
    <div className="card">
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 10 }}>
        <div className="t-headline">Ближайшие списания</div>
        {events.length > 0 && (
          <Link href="/subscriptions" className="t-subheadline" style={{ fontWeight: 500, color: "var(--accent)" }}>
            Все
          </Link>
        )}
      </div>
      {events.length === 0 ? (
        hasAny ? (
          <EmptyState symbol="checkmark.seal" title="В ближайший месяц списаний нет" />
        ) : (
          <EmptyState
            symbol="tray"
            title="Пока нет подписок"
            subtitle="Добавьте первую — Кипер напомнит о списании заранее."
            action={
              <button className="btn-prominent" onClick={onAdd}>
                <Plus size={17} weight="bold" />
                Добавить подписку
              </button>
            }
          />
        )
      ) : (
        <div style={{ display: "flex", flexDirection: "column" }}>
          {events.map((e, i) => {
            const category: Category | null = categories.find((c) => c.id === e.subscription.categoryId) ?? null;
            return (
              <div key={`${e.subscription.id}-${e.date.getTime()}`}>
                {i > 0 && <div className="divider-inset" />}
                <div style={{ padding: "12px 2px", display: "flex", alignItems: "center", gap: 14 }}>
                  <SubscriptionLogo size={44} category={category} domain={e.subscription.domain} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div className="t-body" style={{ fontWeight: 500, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {e.subscription.name}
                    </div>
                    <div className="t-subheadline secondary">
                      {relative(e.date)} · {smartDate(e.date)}
                    </div>
                  </div>
                  <div className="num" style={{ fontWeight: 600, flex: "none", textAlign: "right" }}>
                    {money(e.subscription.amount, e.subscription.currency)}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

