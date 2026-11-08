"use client";

// AnalyticsScreen.swift — spending chart, category rings, month-over-month,
// annual forecast, duplicates.

import { useMemo, useState } from "react";
import { ArrowCircleDown, ArrowCircleUp, ChartBar, Warning } from "@phosphor-icons/react";
import { monthName, rub } from "@/lib/format";
import { periodLabel } from "@/lib/models";
import { annualForecast, categoryShares, duplicateGroups, monthOverMonth, monthlyTotals, toRub, useKiper, weeklyTotals } from "@/lib/store";
import { endOfMonth, startOfMonth } from "@/lib/intervals";
import { SpendingChart, selectedCaption } from "@/components/SpendingChart";
import { Segmented } from "@/components/ui";
import { SubscriptionLogo } from "@/components/SubscriptionViews";

export default function AnalyticsPage() {
  const [mode, setMode] = useState<"month" | "week">("month");
  const [selected, setSelected] = useState<number | null>(null);

  return (
    <div className="page screen-pad" style={{ paddingTop: 8 }}>
      <h1 className="t-title" style={{ margin: "6px 4px 16px" }}>
        Аналитика
      </h1>
      <div className="analytics-grid">
        <SpendingCard mode={mode} setMode={setMode} selected={selected} setSelected={setSelected} />
        <CategoryRingsCard />
        <MonthOverMonthCard />
        <AnnualCostCard />
        <DuplicatesCard />
      </div>
    </div>
  );
}

function SpendingCard({
  mode,
  setMode,
  selected,
  setSelected,
}: {
  mode: "month" | "week";
  setMode: (m: "month" | "week") => void;
  selected: number | null;
  setSelected: (i: number | null) => void;
}) {
  const subs = useKiper((s) => s.subscriptions);
  const payments = useKiper((s) => s.payments);
  const rate = useKiper((s) => s.rateSnapshot);
  const hasAny = useKiper((s) => s.subscriptions.some((x) => x.status === "active" || x.status === "paused"));

  const data = useMemo(() => {
    const state = { subscriptions: subs, payments, rateSnapshot: rate };
    return mode === "month" ? monthlyTotals(state, 6, 3) : weeklyTotals(state, 6, 4);
  }, [subs, payments, rate, mode]);

  const selIndex = selected != null && selected < data.length ? selected : data.length - 1;
  const current = data[selIndex] ?? data[data.length - 1];

  return (
    <div className="card">
      <div style={{ marginBottom: 10 }}>
        <div className="t-headline">{mode === "month" ? "Расходы по месяцам" : "Расходы по неделям"}</div>
        <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
          <span className="rounded-num num t-title2" style={{ fontWeight: 700 }}>
            {rub(current?.amount ?? 0)}
          </span>
          <span className="t-caption secondary">{current ? selectedCaption(current, mode === "week") : ""}</span>
        </div>
      </div>
      {hasAny ? (
        <SpendingChart data={data} weekly={mode === "week"} selected={selIndex} onSelect={setSelected} />
      ) : (
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8, padding: "36px 0" }}>
          <span style={{ color: "var(--label-3)", display: "flex" }}>
            <ChartBar size={30} />
          </span>
          <span className="t-subheadline secondary">Пока нет списаний</span>
        </div>
      )}
      <div style={{ marginTop: 12 }}>
        <Segmented
          options={[
            { value: "month", label: "Месяц" },
            { value: "week", label: "Неделя" },
          ]}
          value={mode}
          onChange={(m) => {
            setMode(m);
            setSelected(null);
          }}
        />
      </div>
    </div>
  );
}

function CategoryRingsCard() {
  const subs = useKiper((s) => s.subscriptions);
  const payments = useKiper((s) => s.payments);
  const rate = useKiper((s) => s.rateSnapshot);
  const now = new Date();
  const categories = useKiper((s) => s.categories);
  const shares = useMemo(
    () => categoryShares({ subscriptions: subs, payments, categories, rateSnapshot: rate }, startOfMonth(now), endOfMonth(now)),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [subs, payments, categories, rate],
  );
  const grand = shares.reduce((sum, s) => sum + s.total, 0);

  return (
    <div className="card">
      <div className="t-headline" style={{ marginBottom: 4 }}>
        По категориям
      </div>
      <div className="t-caption secondary" style={{ marginBottom: 10 }}>
        Списания за {monthName(now).toLowerCase()} · {rub(grand)}
      </div>
      {shares.length === 0 && <div className="t-subheadline secondary" style={{ padding: "12px 0" }}>Нет данных за месяц</div>}
      <div style={{ display: "flex", flexDirection: "column" }}>
        {shares.map((s, i) => {
          const color = `#${(s.category?.colorHex ?? 0x9e9e9e).toString(16).padStart(6, "0")}`;
          const fraction = s.total > 0 ? s.paid / s.total : 0;
          const percent = grand > 0 ? Math.round((s.total / grand) * 100) : 0;
          return (
            <div key={s.category?.id ?? "none"}>
              {i > 0 && <div style={{ height: 0.5, background: "var(--divider)", marginLeft: 40 }} />}
              <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 0" }}>
                <Ring size={28} fraction={fraction} color={color} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="t-body" style={{ fontWeight: 500 }}>
                    {s.category?.name ?? "Без категории"}
                  </div>
                  <div className="t-subheadline secondary num">
                    {rub(s.paid)} из {rub(s.total)}
                  </div>
                </div>
                <span className="num" style={{ fontSize: 20, fontWeight: 600, color }}>
                  {percent}%
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function Ring({ size, fraction, color }: { size: number; fraction: number; color: string }) {
  const r = (size - 5) / 2;
  const c = 2 * Math.PI * r;
  const clamped = Math.max(0, Math.min(1, fraction));
  return (
    <svg width={size} height={size} style={{ flex: "none" }}>
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="color-mix(in srgb, currentColor 14%, transparent)" style={{ color }} strokeWidth={5} />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        stroke={color}
        strokeWidth={5}
        strokeLinecap="round"
        strokeDasharray={c}
        strokeDashoffset={c * (1 - clamped)}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
    </svg>
  );
}

function MonthOverMonthCard() {
  const subs = useKiper((s) => s.subscriptions);
  const payments = useKiper((s) => s.payments);
  const rate = useKiper((s) => s.rateSnapshot);
  const delta = useMemo(() => monthOverMonth({ subscriptions: subs, payments, rateSnapshot: rate }), [subs, payments, rate]);
  if (!delta) return null;
  const up = delta.delta > 0;
  return (
    <div className="card">
      <div className="t-headline" style={{ marginBottom: 8 }}>
        Месяц к месяцу
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <span style={{ color: up ? "#ff9f0a" : "#34c759", display: "flex" }}>
          {up ? <ArrowCircleUp size={30} weight="fill" /> : <ArrowCircleDown size={30} weight="fill" />}
        </span>
        <span className="rounded-num num t-title2" style={{ fontWeight: 700 }}>
          {up ? "+" : "−"}
          {rub(Math.abs(delta.delta))}
        </span>
      </div>
      <div className="t-caption secondary" style={{ marginTop: 8 }}>
        {rub(delta.current)} списано сейчас против {rub(delta.previous)} в прошлом месяце к этому дню
      </div>
    </div>
  );
}

function AnnualCostCard() {
  const subs = useKiper((s) => s.subscriptions);
  const rate = useKiper((s) => s.rateSnapshot);
  const forecast = useMemo(() => annualForecast({ subscriptions: subs, rateSnapshot: rate }), [subs, rate]);
  return (
    <div className="card">
      <div className="t-headline">Годовая стоимость</div>
      <div className="rounded-num num t-title2" style={{ fontWeight: 700, margin: "4px 0 2px" }}>
        {rub(forecast.totalRub)}
      </div>
      <div className="t-caption secondary" style={{ marginBottom: 12 }}>
        если ничего не менять
      </div>
      <div style={{ display: "flex", flexDirection: "column" }}>
        {forecast.top.map((item) => (
          <div key={item.subscription.id} style={{ display: "flex", alignItems: "center", gap: 12, padding: "8px 0" }}>
            <SubscriptionLogo size={40} category={null} domain={item.subscription.domain} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="t-body" style={{ fontWeight: 500, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {item.subscription.name}
              </div>
              <div className="t-caption secondary">{periodLabel[item.subscription.billingPeriod]}</div>
            </div>
            <span className="t-subheadline num" style={{ fontWeight: 600 }}>
              {rub(item.perYearRub)} в год
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function DuplicatesCard() {
  const subs = useKiper((s) => s.subscriptions);
  const categories = useKiper((s) => s.categories);
  const rate = useKiper((s) => s.rateSnapshot);
  const groups = useMemo(() => duplicateGroups({ subscriptions: subs }), [subs]);
  if (groups.length === 0) return null;
  return (
    <div className="card">
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 12 }}>
        <span style={{ color: "var(--accent)", display: "flex" }}>
          <Warning size={17} weight="fill" />
        </span>
        <div className="t-headline">Похожие подписки</div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {groups.map((group, gi) => (
          <div key={gi} className="glass" style={{ borderRadius: 18, padding: 10 }}>
            {group.map((s) => (
              <div key={s.id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "4px 2px" }}>
                <SubscriptionLogo
                  size={32}
                  category={categories.find((c) => c.id === s.categoryId) ?? null}
                  domain={s.domain}
                />
                <span className="t-subheadline" style={{ fontWeight: 500, flex: 1, minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                  {s.name}
                </span>
                <span className="t-subheadline secondary num">{rub(toRub(s.amount, s.currency, { rateSnapshot: rate }))}</span>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
