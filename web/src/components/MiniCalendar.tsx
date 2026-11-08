"use client";

// Inline graphical date picker (iOS .graphical DatePicker): month grid,
// Monday-first, ru_RU month names, accent selection.

import { useMemo, useState } from "react";
import { CaretLeft, CaretRight } from "@phosphor-icons/react";
import { monthName } from "@/lib/format";
import { sameDay, startOfDay } from "@/lib/date";

const WEEKDAYS = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"];

export function MiniCalendar({
  value,
  onChange,
}: {
  value: Date | null;
  onChange: (d: Date) => void;
}) {
  const today = startOfDay(new Date());
  const [month, setMonth] = useState(() => new Date((value ?? today).getFullYear(), (value ?? today).getMonth(), 1));

  const cells = useMemo(() => {
    const first = new Date(month.getFullYear(), month.getMonth(), 1);
    const lead = (first.getDay() + 6) % 7; // Monday-first
    const count = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    const result: (Date | null)[] = Array.from({ length: lead }, () => null);
    for (let d = 1; d <= count; d++) result.push(new Date(month.getFullYear(), month.getMonth(), d));
    return result;
  }, [month]);

  return (
    <div style={{ padding: 12, borderRadius: 18, background: "var(--field-bg)" }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8 }}>
        <button
          aria-label="Предыдущий месяц"
          onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}
          style={{ color: "var(--accent)", display: "flex", padding: 4 }}
        >
          <CaretLeft size={16} weight="bold" />
        </button>
        <div className="t-subheadline" style={{ fontWeight: 600 }}>
          {monthName(month)} {month.getFullYear()}
        </div>
        <button
          aria-label="Следующий месяц"
          onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}
          style={{ color: "var(--accent)", display: "flex", padding: 4 }}
        >
          <CaretRight size={16} weight="bold" />
        </button>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 2, textAlign: "center" }}>
        {WEEKDAYS.map((w) => (
          <div key={w} className="t-caption2 tertiary" style={{ padding: "4px 0" }}>
            {w}
          </div>
        ))}
        {cells.map((d, i) => {
          if (!d) return <div key={`e${i}`} />;
          const selected = value != null && sameDay(d, value);
          const isToday = sameDay(d, today);
          return (
            <button
              key={d.getTime()}
              onClick={() => onChange(d)}
              className="num"
              style={{
                height: 36,
                borderRadius: 18,
                fontSize: 15,
                fontWeight: selected ? 600 : 400,
                background: selected ? "var(--accent)" : "transparent",
                color: selected ? "#fff" : isToday ? "var(--accent)" : "var(--label)",
                transition: "background 0.15s ease",
              }}
            >
              {d.getDate()}
            </button>
          );
        })}
      </div>
    </div>
  );
}
