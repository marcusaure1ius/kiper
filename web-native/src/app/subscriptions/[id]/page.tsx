"use client";

// SubscriptionDetailScreen.swift — hero, schedule info, payment history with
// price-change badge, note, pause/resume/cancel/end-trial actions.

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { CaretLeft, CheckCircle, DotsThree, Money } from "@phosphor-icons/react";
import { daysBetween } from "@/lib/date";
import { fullDate, money, plural, relative, rub, smartDate } from "@/lib/format";
import { monthlyEquivalent, periodLabel, statusLabel } from "@/lib/models";
import { lastCharge, toRub, useKiper } from "@/lib/store";
import { CategoryTag, SubscriptionLogo } from "@/components/SubscriptionViews";
import { useUI } from "@/lib/ui";

export default function SubscriptionDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const id = params?.id;

  const subs = useKiper((s) => s.subscriptions);
  const categories = useKiper((s) => s.categories);
  const payments = useKiper((s) => s.payments);
  const rate = useKiper((s) => s.rateSnapshot);
  const togglePause = useKiper((s) => s.togglePause);
  const endTrial = useKiper((s) => s.endTrial);
  const cancelSub = useKiper((s) => s.cancel);
  const show = useKiper((s) => s.show);
  const openEdit = useUI((s) => s.openEdit);
  const [menuOpen, setMenuOpen] = useState(false);

  const sub = useMemo(() => subs.find((s) => s.id === id) ?? null, [subs, id]);
  const category = sub ? (categories.find((c) => c.id === sub.categoryId) ?? null) : null;
  const last = sub ? lastCharge({ payments }, sub.id) : null;
  const history = useMemo(
    () =>
      sub
        ? payments
            .filter((p) => p.subscriptionId === sub.id && p.kind === "charge")
            .sort((a, b) => b.date.getTime() - a.date.getTime())
            .slice(0, 5)
        : [],
    [payments, sub],
  );

  if (!sub) {
    return (
      <div className="page screen-pad" style={{ paddingTop: 20, textAlign: "center" }}>
        <div className="t-headline">Подписка не найдена</div>
        <Link href="/subscriptions" className="t-body" style={{ color: "var(--accent)", display: "inline-block", marginTop: 12 }}>
          Ко всем подпискам
        </Link>
      </div>
    );
  }

  const perMonth = toRub(sub.amount, sub.currency, { rateSnapshot: rate }) * monthlyEquivalent(sub.billingPeriod);
  const priceChanged = last != null && Math.abs(last.amount - sub.amount) > 1e-9;
  const nextIn = daysBetween(new Date(), sub.nextBillingDate);

  return (
    <div className="page screen-pad" style={{ paddingTop: 6 }}>
      <div className="nav-bar" style={{ position: "static", padding: "6px 0 10px" }}>
        <button
          onClick={() => router.push("/subscriptions")}
          className="glass"
          aria-label="Назад"
          style={{ width: 34, height: 34, borderRadius: 17, display: "flex", alignItems: "center", justifyContent: "center" }}
        >
          <CaretLeft size={16} weight="bold" />
        </button>
        <div style={{ width: 34 }} />
        <div style={{ display: "flex", gap: 8 }}>
          <button className="nav-title" style={{ color: "var(--accent)" }} onClick={() => openEdit(sub.id)}>
            Изменить
          </button>
          <div style={{ position: "relative" }}>
            <button
              className="glass"
              aria-label="Действия"
              onClick={() => setMenuOpen((v) => !v)}
              style={{ width: 34, height: 34, borderRadius: 17, display: "flex", alignItems: "center", justifyContent: "center" }}
            >
              <DotsThree size={18} weight="bold" />
            </button>
            {menuOpen && (
              <>
                <div style={{ position: "fixed", inset: 0, zIndex: 10 }} onClick={() => setMenuOpen(false)} />
                <div
                  className="glass"
                  style={{
                    position: "absolute",
                    right: 0,
                    top: 40,
                    zIndex: 11,
                    borderRadius: 16,
                    minWidth: 220,
                    padding: 6,
                    background: "var(--mat-bg-strong)",
                    boxShadow: "var(--shadow-card)",
                  }}
                >
                  {sub.status === "trial" && (
                    <MenuRow
                      label="Завершить триал"
                      onClick={() => {
                        endTrial(sub.id);
                        setMenuOpen(false);
                        show("Триал завершён");
                      }}
                    />
                  )}
                  {sub.status === "active" && (
                    <MenuRow
                      label="Приостановить"
                      onClick={() => {
                        togglePause(sub.id);
                        setMenuOpen(false);
                        show("Подписка на паузе", "pause.circle.fill", "orange");
                      }}
                    />
                  )}
                  {sub.status === "paused" && (
                    <MenuRow
                      label="Возобновить"
                      onClick={() => {
                        togglePause(sub.id);
                        setMenuOpen(false);
                        show("Подписка возобновлена", "play.fill");
                      }}
                    />
                  )}
                  <MenuRow
                    label="Отменить подписку"
                    destructive
                    onClick={() => {
                      cancelSub(sub.id);
                      setMenuOpen(false);
                      show("Подписка отменена", "xmark.circle.fill", "red");
                      router.push("/subscriptions");
                    }}
                  />
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10, padding: "14px 0 22px" }}>
        <SubscriptionLogo size={84} category={category} domain={sub.domain} />
        <div className="t-title2" style={{ fontWeight: 700 }}>
          {sub.name}
        </div>
        <div className="rounded-num num t-title3" style={{ fontWeight: 600 }}>
          {money(sub.amount, sub.currency)}
        </div>
        {category && <CategoryTag category={category} />}
      </div>

      <div className="inset-list">
        <InfoRow label="Период" value={sub.billingPeriod === "custom" ? `Каждые ${sub.customPeriodDays ?? 30} дн.` : periodLabel[sub.billingPeriod]} />
        <InfoRow
          label="Следующее списание"
          value={`${fullDate(sub.nextBillingDate)} · ${nextIn === 0 ? "сегодня" : relative(sub.nextBillingDate).toLowerCase()}`}
        />
        {sub.status === "trial" && sub.trialEndDate && <InfoRow label="Триал до" value={fullDate(sub.trialEndDate)} />}
        <InfoRow label="Дата начала" value={fullDate(sub.startDate)} />
        <InfoRow label="Статус" value={statusLabel[sub.status]} />
        {sub.reminderDaysBefore > 0 && <InfoRow label="Напоминание" value={`За ${sub.reminderDaysBefore} дн.`} />}
        <InfoRow label="В месяц" value={rub(perMonth)} />
      </div>

      <div className="section-label" style={{ paddingLeft: 4 }}>
        История платежей
      </div>
      <div className="inset-list">
        {priceChanged && (
          <div className="inset-row">
            <span style={{ color: "#ff9f0a", display: "flex" }}>
              <Money size={17} weight="fill" />
            </span>
            <span className="t-body" style={{ fontWeight: 600, color: "#ff9f0a" }}>
              Цена изменилась
            </span>
            <span className="t-subheadline secondary num" style={{ marginLeft: "auto" }}>
              было {money(last!.amount, last!.currency)} → стало {money(sub.amount, sub.currency)}
            </span>
          </div>
        )}
        {history.length === 0 ? (
          <div className="inset-row">
            <span className="t-subheadline secondary">Платежей ещё не было</span>
          </div>
        ) : (
          history.map((p, i) => (
            <div className="inset-row" key={p.id}>
              <span style={{ color: "#34c759", display: "flex" }}>
                <CheckCircle size={17} weight="fill" />
              </span>
              <span className="t-body">{smartDate(p.date)}</span>
              <span className="t-body num" style={{ marginLeft: "auto", fontWeight: 600 }}>
                {money(p.amount, p.currency)}
              </span>
            </div>
          ))
        )}
      </div>

      {sub.note && (
        <>
          <div className="section-label" style={{ paddingLeft: 4 }}>
            Заметка
          </div>
          <div className="card">
            <div className="t-body" style={{ whiteSpace: "pre-wrap" }}>
              {sub.note}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="inset-row">
      <span className="t-body secondary">{label}</span>
      <span className="t-body num" style={{ marginLeft: "auto", textAlign: "right" }}>
        {value}
      </span>
    </div>
  );
}

function MenuRow({ label, onClick, destructive }: { label: string; onClick: () => void; destructive?: boolean }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: "block",
        width: "100%",
        textAlign: "left",
        padding: "10px 12px",
        borderRadius: 10,
        fontSize: 16,
        fontWeight: 500,
        color: destructive ? "#ff453a" : "var(--label)",
      }}
    >
      {label}
    </button>
  );
}
