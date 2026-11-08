"use client";

// SubscriptionRow / SubscriptionLogo / CategoryTag / CategoryChips — ports of
// the iOS list visuals (Shared/Components.swift, GlassChips.swift).

import { useState } from "react";
import { Tray } from "@phosphor-icons/react";
import { Category, Subscription, logoURL } from "@/lib/models";
import { rgba } from "@/lib/palette";
import { money, rub } from "@/lib/format";
import { Sym } from "./Sym";
import { useTheme } from "./theme";

/// Rounded tile with the category-color gradient at 18%, favicon inside
/// (Google s2 like iOS), category SF Symbol as fallback.
export function SubscriptionLogo({
  size,
  category,
  domain,
}: {
  size: number;
  category: Category | null;
  domain: string | null;
}) {
  const [failed, setFailed] = useState(false);
  const color = category?.colorHex ?? 0x8e8e93;
  const url = logoURL(domain);
  const showImage = url != null && !failed;
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.28,
        flex: "none",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: `linear-gradient(160deg, ${rgba(color, 0.22)}, ${rgba(color, 0.1)})`,
        overflow: "hidden",
      }}
    >
      {showImage ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={url}
          alt=""
          width={Math.round(size * 0.64)}
          height={Math.round(size * 0.64)}
          style={{ borderRadius: Math.round(size * 0.14), objectFit: "cover" }}
          onError={() => setFailed(true)}
          loading="lazy"
        />
      ) : (
        <span style={{ color: `#${color.toString(16).padStart(6, "0")}`, display: "flex" }}>
          <Sym name={category?.symbol ?? "creditcard.fill"} size={Math.round(size * 0.42)} />
        </span>
      )}
    </div>
  );
}

/// Right-aligned amount: original currency + «≈ N ₽» for non-ruble prices.
export function AmountLabel({
  amount,
  currency,
  amountRub,
  size = 17,
}: {
  amount: number;
  currency: Subscription["currency"];
  amountRub: number;
  size?: number;
}) {
  return (
    <div style={{ textAlign: "right", flex: "none" }}>
      <div className="num" style={{ fontWeight: 600, fontSize: size }}>
        {money(amount, currency)}
      </div>
      {currency !== "RUB" && <div className="t-caption secondary num">≈ {rub(amountRub)}</div>}
    </div>
  );
}

export function SubscriptionRow({
  sub,
  category,
  amountRub,
  subtitle,
  dimmed,
}: {
  sub: Subscription;
  category: Category | null;
  amountRub: number;
  subtitle?: string;
  dimmed?: boolean;
}) {
  return (
    <div
      className="row-card"
      style={{
        display: "flex",
        alignItems: "center",
        gap: 14,
        padding: 14,
        opacity: dimmed ? 0.55 : 1,
      }}
    >
      <SubscriptionLogo size={44} category={category} domain={sub.domain} />
      <div style={{ minWidth: 0, flex: 1, display: "flex", flexDirection: "column", gap: 3 }}>
        <div className="t-body" style={{ fontWeight: 500, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {sub.name}
        </div>
        {subtitle && <div className="t-subheadline secondary">{subtitle}</div>}
      </div>
      <AmountLabel amount={sub.amount} currency={sub.currency} amountRub={amountRub} />
    </div>
  );
}

/// Capsule with the category color (detail screen).
export function CategoryTag({ category }: { category: Category }) {
  const { dark } = useTheme();
  const bgAlpha = dark ? 0.24 : 0.14;
  const fg = mixWithNeutral(category.colorHex, dark, 0.15);
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 5,
        padding: "6px 12px",
        borderRadius: 100,
        background: rgba(category.colorHex, bgAlpha),
        color: fg,
        fontSize: 15,
        fontWeight: 600,
      }}
    >
      <Sym name={category.symbol} size={13} />
      {category.name}
    </span>
  );
}

function mixWithNeutral(color: number, dark: boolean, by: number): string {
  const channel = (shift: number) => {
    const c = (color >> shift) & 0xFF;
    const neutral = dark ? 0x00 : 0xFF;
    return Math.round(c * (1 - by) + neutral * by);
  };
  return `rgb(${channel(16)}, ${channel(8)}, ${channel(0)})`;
}

/// Horizontal glass chips: «Все» + one per category (GlassChips.swift).
export function CategoryChips({
  categories,
  selected,
  onSelect,
}: {
  categories: Category[];
  selected: string | null; // null = «Все»
  onSelect: (id: string | null) => void;
}) {
  return (
    <div className="scroll-x" style={{ padding: "2px 16px 10px" }}>
      <button
        className={`chip ${selected === null ? "on" : ""}`}
        style={selected === null ? { background: "color-mix(in srgb, var(--accent) 72%, transparent)", borderColor: "transparent" } : undefined}
        onClick={() => onSelect(null)}
      >
        <Tray size={15} weight="fill" />
        Все
      </button>
      {categories.map((c) => {
        const isOn = selected === c.id;
        return (
          <button
            key={c.id}
            className={`chip ${isOn ? "on" : ""}`}
            style={isOn ? { background: `color-mix(in srgb, ${rgba(c.colorHex, 0.85)}, transparent)`, borderColor: "transparent" } : undefined}
            onClick={() => onSelect(c.id)}
          >
            <span style={{ color: isOn ? "#fff" : rgba(c.colorHex, 1), display: "flex" }}>
              <Sym name={c.symbol} size={15} />
            </span>
            {c.name}
          </button>
        );
      })}
    </div>
  );
}
