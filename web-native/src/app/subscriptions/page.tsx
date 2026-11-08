"use client";

// SubscriptionsListScreen.swift — search, category chips, total header,
// subscription rows.

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { MagnifyingGlass, Plus, Tray, X } from "@phosphor-icons/react";
import { relative, rub, smartDate } from "@/lib/format";
import { periodLabel, statusLabel, Subscription } from "@/lib/models";
import { monthlyTotalRub, toRub, useKiper } from "@/lib/store";
import { CategoryChips, SubscriptionRow } from "@/components/SubscriptionViews";
import { useUI } from "@/lib/ui";

export default function SubscriptionsPage() {
  const subs = useKiper((s) => s.subscriptions);
  const categories = useKiper((s) => s.categories);
  const rate = useKiper((s) => s.rateSnapshot);
  const total = useKiper((s) => (s.hydrated ? monthlyTotalRub(s) : 0));
  const openAdd = useUI((s) => s.openAdd);

  const [query, setQuery] = useState("");
  const [category, setCategory] = useState<string | null>(null);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 6);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const active = useMemo(() => subs.filter((s) => s.status !== "cancelled"), [subs]);
  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return active
      .filter((s) => (category == null || s.categoryId === category) && (!q || s.name.toLowerCase().includes(q)))
      .sort((a, b) => a.nextBillingDate.getTime() - b.nextBillingDate.getTime());
  }, [active, category, query]);

  const subtitle = (s: Subscription): string => {
    if (s.status === "paused") return "Приостановлена";
    if (s.status === "trial") return `Триал до ${smartDate(s.trialEndDate ?? s.nextBillingDate)}`;
    return `${periodLabel[s.billingPeriod]} · ${smartDate(s.nextBillingDate)}`;
  };

  return (
    <div className="page">
      <div className={`nav-bar ${scrolled ? "scrolled" : ""}`}>
        <h1 className="t-title" style={{ margin: 0 }}>
          Подписки
        </h1>
        <div style={{ display: "flex", alignItems: "center", gap: 8, flex: 1, maxWidth: 300, marginLeft: 12 }}>
          <div style={{ position: "relative", flex: 1 }}>
            <span style={{ position: "absolute", left: 10, top: 9, color: "var(--label-3)", display: "flex" }}>
              <MagnifyingGlass size={14} />
            </span>
            <input
              className="field"
              style={{ paddingLeft: 32, paddingRight: 30, paddingBlock: 8, fontSize: 15 }}
              placeholder="Поиск"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
            {query && (
              <button aria-label="Очистить" onClick={() => setQuery("")} style={{ position: "absolute", right: 8, top: 8, color: "var(--label-3)", display: "flex" }}>
                <X size={13} weight="bold" />
              </button>
            )}
          </div>
        </div>
        <button
          onClick={() => openAdd()}
          aria-label="Добавить"
          className="glass tap-scale"
          style={{ width: 34, height: 34, borderRadius: 17, display: "flex", alignItems: "center", justifyContent: "center", flex: "none" }}
        >
          <Plus size={18} weight="bold" />
        </button>
      </div>

      <div style={{ position: "sticky", top: 54, zIndex: 29 }}>
        <CategoryChips categories={categories} selected={category} onSelect={setCategory} />
      </div>

      <div className="screen-pad">
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", padding: "2px 4px 10px" }}>
          <span className="t-subheadline secondary">
            {active.length} {pluralActive(active.length)}
          </span>
          <span className="t-headline num">{rub(total)} / мес</span>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {visible.map((s) => (
            <Link key={s.id} href={`/subscriptions/${s.id}`} className="tap-scale" style={{ display: "block", borderRadius: 22 }}>
              <SubscriptionRow
                sub={s}
                category={categories.find((c) => c.id === s.categoryId) ?? null}
                amountRub={toRub(s.amount, s.currency, { rateSnapshot: rate })}
                subtitle={subtitle(s)}
                dimmed={s.status === "paused"}
              />
            </Link>
          ))}
        </div>

        {visible.length === 0 && (
          <div style={{ textAlign: "center", padding: "48px 16px" }}>
            <span style={{ color: "var(--label-3)", display: "inline-flex", marginBottom: 10 }}>
              <Tray size={40} />
            </span>
            <div className="t-headline">
              {active.length === 0
                ? "Пока нет подписок"
                : query
                  ? "Не найдено"
                  : "В этой категории пусто"}
            </div>
            <div className="t-footnote secondary" style={{ marginTop: 6 }}>
              {active.length === 0 ? "Добавьте первую подписку — Кипер всё посчитает сам." : "Попробуйте другой запрос или категорию."}
            </div>
            {active.length === 0 && (
              <button className="btn-prominent" style={{ marginTop: 18, width: "min(260px,100%)" }} onClick={() => openAdd()}>
                <Plus size={17} weight="bold" />
                Добавить подписку
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

function pluralActive(n: number): string {
  const n10 = n % 10, n100 = n % 100;
  if (n10 === 1 && n100 !== 11) return "активная";
  if (n10 >= 2 && n10 <= 4 && !(n100 >= 12 && n100 <= 14)) return "активные";
  return "активных";
}
