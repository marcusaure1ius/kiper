"use client";

// Shared UI primitives: sheet, segmented control, switch, empty state,
// count-up hook, toast host. Styling mirrors the iOS app's Liquid Glass look.

import { useEffect, useRef, useState } from "react";
import { X } from "@phosphor-icons/react";
import { useKiper } from "@/lib/store";
import { Sym } from "./Sym";
import type { ToastTint } from "@/lib/store";

export const TINT_HEX: Record<ToastTint, string> = {
  green: "#34c759",
  orange: "#ff9f0a",
  red: "#ff453a",
};

/// iOS sheets: inline title, close button, grabber on mobile; centered dialog
/// on desktop (see .sheet media query in globals.css).
export function Sheet({
  open,
  onClose,
  title,
  detent = "full",
  trailing,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  detent?: "half" | "full";
  trailing?: React.ReactNode;
  children: React.ReactNode;
}) {
  const [expanded, setExpanded] = useState(false);
  const [visible, setVisible] = useState(open);

  useEffect(() => {
    if (open) {
      setVisible(true);
      setExpanded(detent === "full");
    } else {
      setVisible(false);
    }
  }, [open, detent]);

  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  if (!visible) return null;
  return (
    <>
      <div className="sheet-backdrop" onClick={onClose} />
      <div
        className={`sheet ${open ? (expanded ? "full" : "half") : detent}`}
        role="dialog"
        aria-modal
        aria-label={title}
      >
        <button className="grabber-btn" aria-label="Развернуть" onClick={() => setExpanded((v) => !v)}>
          <span className="grabber" />
        </button>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            padding: "8px 16px 10px",
            flex: "none",
          }}
        >
          <button
            onClick={onClose}
            aria-label="Закрыть"
            className="glass"
            style={{
              width: 34,
              height: 34,
              borderRadius: 17,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              color: "var(--label-2)",
            }}
          >
            <X size={16} weight="bold" />
          </button>
          <div className="nav-title">{title}</div>
          <div style={{ minWidth: 34, display: "flex", justifyContent: "flex-end" }}>{trailing}</div>
        </div>
        <div style={{ overflowY: "auto", flex: 1, padding: "0 16px calc(20px + env(safe-area-inset-bottom))" }}>
          {children}
        </div>
      </div>
    </>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="seg" role="tablist">
      {options.map((o) => (
        <button
          key={o.value}
          role="tab"
          aria-selected={value === o.value}
          className={value === o.value ? "on" : ""}
          onClick={() => onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function Switch({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label: string }) {
  return (
    <button
      role="switch"
      aria-checked={on}
      aria-label={label}
      className={`switch ${on ? "on" : ""}`}
      onClick={() => onChange(!on)}
    />
  );
}

export function EmptyState({
  symbol,
  title,
  subtitle,
  action,
}: {
  symbol: string;
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8, padding: "28px 16px 22px", textAlign: "center" }}>
      <span style={{ color: "var(--accent)", marginBottom: 4 }}>
        <Sym name={symbol} size={34} />
      </span>
      <div className="t-subheadline" style={{ fontWeight: 600 }}>
        {title}
      </div>
      {subtitle && <div className="t-footnote secondary">{subtitle}</div>}
      {action && <div style={{ marginTop: 14, width: "min(260px, 100%)" }}>{action}</div>}
    </div>
  );
}

/// Counts up to `value` on change (CountUpRub / .numericText transition).
export function useCountUp(value: number, durationMs = 550): number {
  const [display, setDisplay] = useState(value);
  const fromRef = useRef(value);
  const rafRef = useRef(0);

  useEffect(() => {
    const from = fromRef.current;
    const to = value;
    if (from === to) return;
    const start = performance.now();
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / durationMs);
      const eased = 1 - Math.pow(1 - t, 3);
      const current = from + (to - from) * eased;
      setDisplay(current);
      fromRef.current = current;
      if (t < 1) rafRef.current = requestAnimationFrame(tick);
      else fromRef.current = to;
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [value, durationMs]);

  return display;
}

export function ToastHost() {
  const toast = useKiper((s) => s.toast);
  const dismiss = useKiper((s) => s.dismissToast);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(dismiss, 2200);
    return () => clearTimeout(t);
  }, [toast, dismiss]);

  if (!toast) return null;
  return (
    <div className="toast" key={toast.id}>
      <span style={{ color: TINT_HEX[toast.tint], display: "flex" }}>
        <Sym name={toast.symbol} size={20} />
      </span>
      <span>{toast.text}</span>
    </div>
  );
}
