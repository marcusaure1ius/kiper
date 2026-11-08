"use client";

// Port of SubscriptionForm (SubscriptionFormScreen.swift): name, amount +
// currency, period, category, trial with expandable calendars, reminder, note.

import { useEffect, useMemo, useState } from "react";
import { CaretRight, Check, Minus, Plus } from "@phosphor-icons/react";
import { CatalogEntry } from "@/lib/catalog";
import { addDays, startOfDay } from "@/lib/date";
import { money, rub, smartDate } from "@/lib/format";
import { BillingPeriod, Currency, CURRENCIES, PERIODS, Subscription, periodLabel, currencySymbol } from "@/lib/models";
import { toRub, useKiper } from "@/lib/store";
import { FormPreset } from "@/lib/ui";
import { MiniCalendar } from "./MiniCalendar";
import { Sym } from "./Sym";
import { Switch } from "./ui";

const REMINDERS: { value: number; label: string }[] = [
  { value: 0, label: "Выключено" },
  { value: 1, label: "За 1 день" },
  { value: 3, label: "За 3 дня" },
  { value: 7, label: "За 7 дней" },
];

function parseAmount(text: string): number {
  const normalized = text.replace(/\s/g, "").replace(",", ".");
  const value = Number.parseFloat(normalized);
  return Number.isNaN(value) ? 0 : value;
}

function currencyOf(entry?: CatalogEntry): Currency {
  return entry?.currency ?? "RUB";
}

export function SubscriptionForm({
  editing,
  preset,
  onDone,
}: {
  editing?: Subscription | null;
  preset?: FormPreset | null;
  onDone: () => void;
}) {
  const categories = useKiper((s) => s.categories);
  const rate = useKiper((s) => s.rateSnapshot);
  const upsert = useKiper((s) => s.upsert);
  const show = useKiper((s) => s.show);

  const entry = preset?.entry;
  const [name, setName] = useState(editing?.name ?? preset?.name ?? entry?.name ?? "");
  const [amountText, setAmountText] = useState(
    editing ? String(editing.amount) : preset?.amount != null ? String(preset.amount) : "",
  );
  const [currency, setCurrency] = useState<Currency>(editing?.currency ?? currencyOf(entry));
  const [period, setPeriod] = useState<BillingPeriod>(editing?.billingPeriod ?? entry?.period ?? "monthly");
  const [customDays, setCustomDays] = useState(editing?.customPeriodDays ?? 30);
  const [categoryId, setCategoryId] = useState<string | null>(
    editing ? editing.categoryId : (entry?.categoryId ?? null),
  );
  const [trial, setTrial] = useState(editing?.status === "trial");
  const today = startOfDay(new Date());
  const [trialEnd, setTrialEnd] = useState<Date>(editing?.trialEndDate ?? addDays(today, 7));
  const [nextDate, setNextDate] = useState<Date>(editing?.nextBillingDate ?? today);
  const [reminder, setReminder] = useState(editing?.reminderDaysBefore ?? 1);
  const [note, setNote] = useState(editing?.note ?? "");
  const [openCalendar, setOpenCalendar] = useState<"trial" | "next" | null>(null);
  const [openPicker, setOpenPicker] = useState<"period" | "category" | "reminder" | null>(null);

  const amount = parseAmount(amountText);
  const amountRub = useMemo(() => toRub(amount, currency, { rateSnapshot: rate }), [amount, currency, rate]);
  const valid = name.trim().length > 0 && amount > 0;

  useEffect(() => {
    const t = setTimeout(() => {
      document.getElementById("sub-name")?.focus();
    }, 300);
    return () => clearTimeout(t);
  }, []);

  function save() {
    if (!valid) return;
    const sub: Subscription = {
      id: editing?.id ?? crypto.randomUUID(),
      name: name.trim(),
      amount,
      currency,
      billingPeriod: period,
      customPeriodDays: period === "custom" ? customDays : null,
      categoryId,
      nextBillingDate: nextDate,
      reminderDaysBefore: reminder,
      status: trial ? "trial" : (editing?.status === "paused" ? "paused" : "active"),
      trialEndDate: trial ? trialEnd : null,
      startDate: trial && !editing ? addDays(trialEnd, 1) : (editing?.startDate ?? today),
      note: note.trim() ? note.trim() : null,
      domain: editing?.domain ?? preset?.entry?.domain ?? null,
      createdAt: editing?.createdAt ?? new Date(),
      icon: editing?.icon ?? null,
    };
    upsert(sub);
    show(editing ? "Изменения сохранены" : "Подписка добавлена");
    onDone();
  }

  const periodOptions: BillingPeriod[] = [...PERIODS];

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      <Section>
        <div className="inset-row" style={{ padding: 4 }}>
          <input
            id="sub-name"
            className="field"
            placeholder="Название"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoComplete="off"
          />
        </div>
        <div className="inset-row">
          <span className="t-body secondary" style={{ flex: "none" }}>
            Сумма
          </span>
          <input
            className="field num"
            style={{ flex: 1, minWidth: 0, textAlign: "right" }}
            placeholder="0"
            inputMode="decimal"
            value={amountText}
            onChange={(e) => setAmountText(e.target.value)}
          />
          <div className="seg" style={{ flex: "none" }}>
            {CURRENCIES.map((c) => (
              <button key={c} className={currency === c ? "on" : ""} onClick={() => setCurrency(c)} aria-label={c}>
                {currencySymbol[c]}
              </button>
            ))}
          </div>
        </div>
        {currency !== "RUB" && (
          <div className="inset-row">
            <span className="t-body">В рублях</span>
            <span className="t-body secondary num" style={{ marginLeft: "auto" }}>
              ≈ {rub(amountRub)}
            </span>
          </div>
        )}
      </Section>

      <Section>
        <PickerRow
          label="Период"
          value={periodLabel[period]}
          open={openPicker === "period"}
          onToggle={() => setOpenPicker(openPicker === "period" ? null : "period")}
        >
          {periodOptions.map((p) => (
            <PickerOption key={p} label={periodLabel[p]} selected={p === period} onSelect={() => { setPeriod(p); setOpenPicker(null); }} />
          ))}
        </PickerRow>
        {period === "custom" && (
          <div className="inset-row">
            <span className="t-body">Каждые</span>
            <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 12 }}>
              <button
                aria-label="Меньше"
                onClick={() => setCustomDays((d) => Math.max(1, d - 1))}
                style={{ width: 30, height: 30, borderRadius: 15, background: "var(--field-bg)", display: "flex", alignItems: "center", justifyContent: "center" }}
              >
                <Minus size={14} weight="bold" />
              </button>
              <span className="t-body num" style={{ minWidth: 76, textAlign: "center" }}>
                {customDays} дн.
              </span>
              <button
                aria-label="Больше"
                onClick={() => setCustomDays((d) => Math.min(365, d + 1))}
                style={{ width: 30, height: 30, borderRadius: 15, background: "var(--field-bg)", display: "flex", alignItems: "center", justifyContent: "center" }}
              >
                <Plus size={14} weight="bold" />
              </button>
            </div>
          </div>
        )}
        <PickerRow
          label="Категория"
          value={categoryName(categories, categoryId)}
          open={openPicker === "category"}
          onToggle={() => setOpenPicker(openPicker === "category" ? null : "category")}
        >
          <PickerOption label="Без категории" selected={categoryId == null} onSelect={() => { setCategoryId(null); setOpenPicker(null); }} />
          {categories.map((c) => (
            <PickerOption
              key={c.id}
              label={c.name}
              symbol={c.symbol}
              tint={`#${c.colorHex.toString(16).padStart(6, "0")}`}
              selected={c.id === categoryId}
              onSelect={() => { setCategoryId(c.id); setOpenPicker(null); }}
            />
          ))}
        </PickerRow>
      </Section>

      <Section>
        <div className="inset-row">
          <span className="t-body" style={{ flex: 1 }}>
            Триал (бесплатный период)
          </span>
          <Switch
            on={trial}
            label="Триал"
            onChange={(v) => {
              setTrial(v);
              if (v && !editing) setNextDate(addDays(trialEnd, 1));
            }}
          />
        </div>
        {trial ? (
          <>
            <DateRow
              label="Окончание триала"
              date={trialEnd}
              open={openCalendar === "trial"}
              onToggle={() => setOpenCalendar(openCalendar === "trial" ? null : "trial")}
              onChange={(d) => setTrialEnd(startOfDay(d))}
            />
            <DateRow
              label="Первое списание"
              date={nextDate}
              open={openCalendar === "next"}
              onToggle={() => setOpenCalendar(openCalendar === "next" ? null : "next")}
              onChange={(d) => setNextDate(startOfDay(d))}
            />
          </>
        ) : (
          <DateRow
            label="Дата списания"
            date={nextDate}
            open={openCalendar === "next"}
            onToggle={() => setOpenCalendar(openCalendar === "next" ? null : "next")}
            onChange={(d) => setNextDate(startOfDay(d))}
          />
        )}
        <PickerRow
          label="Напоминание"
          value={REMINDERS.find((r) => r.value === reminder)?.label ?? "За 1 день"}
          open={openPicker === "reminder"}
          onToggle={() => setOpenPicker(openPicker === "reminder" ? null : "reminder")}
        >
          {REMINDERS.map((r) => (
            <PickerOption key={r.value} label={r.label} selected={r.value === reminder} onSelect={() => { setReminder(r.value); setOpenPicker(null); }} />
          ))}
        </PickerRow>
      </Section>

      <Section>
        <div className="inset-row" style={{ padding: 4 }}>
          <textarea
            className="field"
            placeholder="Необязательно"
            rows={2}
            value={note}
            onChange={(e) => setNote(e.target.value)}
            style={{ resize: "none" }}
          />
        </div>
      </Section>

      <button className="btn-prominent" disabled={!valid} onClick={save}>
        {editing ? "Сохранить" : "Добавить"}
      </button>
    </div>
  );
}

function categoryName(categories: { id: string; name: string }[], id: string | null): string {
  if (!id) return "Без категории";
  return categories.find((c) => c.id === id)?.name ?? "Без категории";
}

function Section({ children }: { children: React.ReactNode }) {
  return <div className="inset-list">{children}</div>;
}

function PickerRow({
  label,
  value,
  open,
  onToggle,
  children,
}: {
  label: string;
  value: string;
  open: boolean;
  onToggle: () => void;
  children: React.ReactNode;
}) {
  return (
    <>
      <button className="inset-row" style={{ width: "100%", textAlign: "left" }} onClick={onToggle}>
        <span className="t-body">{label}</span>
        <span className="t-body" style={{ marginLeft: "auto", color: open ? "var(--accent)" : "var(--label-2)", display: "flex", alignItems: "center", gap: 6 }}>
          {value}
          <CaretRight size={12} weight="bold" style={{ transform: open ? "rotate(90deg)" : "none", transition: "transform 0.2s" }} />
        </span>
      </button>
      {open && <div style={{ padding: "0 12px 12px" }}>{children}</div>}
    </>
  );
}

function PickerOption({
  label,
  selected,
  onSelect,
  symbol,
  tint,
}: {
  label: string;
  selected: boolean;
  onSelect: () => void;
  symbol?: string;
  tint?: string;
}) {
  return (
    <button
      onClick={onSelect}
      className="inset-row"
      style={{ width: "100%", minHeight: 42, textAlign: "left", borderRadius: 12 }}
    >
      {symbol && tint && (
        <span style={{ color: tint, display: "flex" }}>
          <Sym name={symbol} size={16} />
        </span>
      )}
      <span className="t-body">{label}</span>
      {selected && (
        <span style={{ marginLeft: "auto", color: "var(--accent)", display: "flex" }}>
          <Check size={16} weight="bold" />
        </span>
      )}
    </button>
  );
}

function DateRow({
  label,
  date,
  open,
  onToggle,
  onChange,
}: {
  label: string;
  date: Date;
  open: boolean;
  onToggle: () => void;
  onChange: (d: Date) => void;
}) {
  return (
    <>
      <button className="inset-row" style={{ width: "100%", textAlign: "left" }} onClick={onToggle}>
        <span className="t-body">{label}</span>
        <span className="t-body num" style={{ marginLeft: "auto", color: open ? "var(--accent)" : "var(--label-2)" }}>
          {smartDate(date)}
        </span>
      </button>
      {open && (
        <div style={{ padding: "0 12px 12px" }}>
          <MiniCalendar value={date} onChange={onChange} />
        </div>
      )}
    </>
  );
}
