"use client";

// App shell: ambient background, mobile tab bar + next-charge accessory,
// desktop sidebar, global sheets and toasts. Port of RootTabView.swift.

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useMemo } from "react";
import { ChartPie, Gear, House } from "@phosphor-icons/react";
import { futurePayments, monthlyTotalRub, toRub, useKiper } from "@/lib/store";
import { relative, rub } from "@/lib/format";
import { Category, PaymentEvent } from "@/lib/models";
import { sameDay, startOfDay } from "@/lib/date";
import { AmbientBackground } from "./AmbientBackground";
import { SubscriptionLogo } from "./SubscriptionViews";
import { ToastHost } from "./ui";
import { PaymentsSheet } from "./PaymentsSheet";
import { AddSheet } from "./AddSheet";
import { EditSheet } from "./EditSheet";
import { CategoryEditorSheet } from "./CategoryEditorSheet";
import { useUI } from "@/lib/ui";
import { useTheme } from "./theme";

const TABS = [
  { href: "/", label: "Главная", icon: House },
  { href: "/analytics", label: "Аналитика", icon: ChartPie },
  { href: "/settings", label: "Настройки", icon: Gear },
];

export function AppShell({ children }: { children: React.ReactNode }) {
  const hydrate = useKiper((s) => s.hydrate);
  const hydrated = useKiper((s) => s.hydrated);
  const loadDemoData = useKiper((s) => s.loadDemoData);

  useEffect(() => {
    hydrate();
    const onVisible = () => {
      if (!document.hidden) hydrate();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
  }, [hydrate]);

  useEffect(() => {
    if (process.env.NODE_ENV !== "production") {
      (window as unknown as Record<string, unknown>).__kiperDemo = loadDemoData;
    }
  }, [loadDemoData]);

  return (
    <>
      <AmbientBackground />
      <Sidebar />
      <main className="content">{hydrated ? children : <Splash />}</main>
      <NextPaymentAccessory />
      <TabBar />
      <PaymentsSheet />
      <AddSheet />
      <EditSheet />
      <CategoryEditorSheet />
      <ToastHost />
    </>
  );
}

function Splash() {
  return (
    <div style={{ display: "grid", placeItems: "center", minHeight: "100dvh" }}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/icons/icon-192.png" alt="Кипер" width={72} height={72} style={{ borderRadius: 20, opacity: 0.9 }} />
    </div>
  );
}

function TabBar() {
  const pathname = usePathname();
  return (
    <nav className="tab-bar">
      {TABS.map((tab) => {
        const on = pathname === tab.href || (tab.href !== "/" && pathname.startsWith(tab.href));
        const Icon = tab.icon;
        return (
          <Link key={tab.href} href={tab.href} className={on ? "on" : ""} aria-current={on ? "page" : undefined}>
            <Icon size={24} weight="fill" />
            {tab.label}
          </Link>
        );
      })}
    </nav>
  );
}

function Sidebar() {
  const pathname = usePathname();
  const total = useKiper((s) => (s.hydrated ? monthlyTotalRub(s) : 0));
  return (
    <aside className="sidebar">
      <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "4px 10px 16px" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/icons/icon-192.png" alt="" width={36} height={36} style={{ borderRadius: 10 }} />
        <div className="t-title3" style={{ fontWeight: 700 }}>
          Кипер
        </div>
      </div>
      {TABS.map((tab) => {
        const on = pathname === tab.href || (tab.href !== "/" && pathname.startsWith(tab.href));
        const Icon = tab.icon;
        return (
          <Link key={tab.href} href={tab.href} className={on ? "on" : ""}>
            <Icon size={22} weight="fill" />
            {tab.label}
          </Link>
        );
      })}
      <div style={{ flex: 1 }} />
      <div className="glass" style={{ borderRadius: 18, padding: 12 }}>
        <div className="t-caption secondary">Всего в месяц</div>
        <div className="rounded-num num" style={{ fontSize: 22, fontWeight: 700 }}>
          {rub(total)}
        </div>
      </div>
      <div className="t-caption2 tertiary" style={{ padding: "10px 12px 0" }}>
        Версия 1.0.0
      </div>
    </aside>
  );
}

/// The glass bar above the tab bar: nearest charge day with stacked logos
/// (NextPaymentAccessory). Hidden on the detail screen, like iOS.
function NextPaymentAccessory() {
  const pathname = usePathname();
  const subs = useKiper((s) => s.subscriptions);
  const categories = useKiper((s) => s.categories);
  const rate = useKiper((s) => s.rateSnapshot);
  const openPayments = useUI((s) => s.openPayments);

  const day = useMemo(() => {
    if (subs.length === 0) return null;
    const events = futurePayments({ subscriptions: subs }, 45);
    if (events.length === 0) return null;
    const firstDay = startOfDay(events[0].date);
    const eventsOnDay = events.filter((e) => sameDay(e.date, firstDay));
    return { events: eventsOnDay };
  }, [subs]);

  if (pathname.startsWith("/subscriptions/")) return null;
  if (!day || day.events.length === 0) return null;

  const events = day.events;
  const first = events[0];
  const names = events.slice(0, 3).map((e) => e.subscription.name);
  if (events.length > 3) names.push(`и ещё ${events.length - 3}`);
  const title = names.join(" и ");
  const total = events.reduce((sum, e) => sum + toRub(e.subscription.amount, e.subscription.currency, { rateSnapshot: rate }), 0);
  const categoryFor = (e: PaymentEvent): Category | null => categories.find((c) => c.id === e.subscription.categoryId) ?? null;

  return (
    <button className="accessory tap-scale" onClick={() => openPayments("upcoming")} style={{ width: "calc(100% - 24px)" }}>
      <div style={{ display: "flex", flex: "none" }}>
        {events.slice(0, 3).map((e, i) => (
          <div key={e.subscription.id} style={{ marginLeft: i === 0 ? 0 : -12, zIndex: 3 - i }}>
            <SubscriptionLogo size={28} category={categoryFor(e)} domain={e.subscription.domain} />
          </div>
        ))}
      </div>
      <div style={{ flex: 1, minWidth: 0, textAlign: "left" }}>
        <div className="t-footnote" style={{ fontWeight: 600, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {title}
        </div>
        <div className="t-caption secondary">Следующее списание · {relative(first.date).toLowerCase()}</div>
      </div>
      <div className="num" style={{ fontWeight: 600, fontSize: 15, flex: "none" }}>
        {rub(total)}
      </div>
    </button>
  );
}
