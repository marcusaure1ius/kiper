"use client";

// SpendingChartCard.swift — tap-to-select bar chart (paid vs forecast),
// «Nк» axis labels, segmented period picker below.

import { monthShort, rub } from "@/lib/format";
import { PeriodTotal } from "@/lib/models";

function niceMax(values: number[]): number {
  const max = Math.max(1, ...values);
  const magnitude = Math.pow(10, Math.floor(Math.log10(max)));
  for (const m of [1, 2, 2.5, 5, 10]) {
    const bound = magnitude * m;
    if (max <= bound) return bound;
  }
  return magnitude * 10;
}

function axisLabel(value: number): string {
  if (value >= 1000000) return `${Math.round(value / 1000000)}м`;
  if (value >= 1000) return `${Math.round(value / 1000)}к`;
  return String(Math.round(value));
}

function barLabel(total: PeriodTotal, weekly: boolean): string {
  if (weekly) return `${total.start.getDate()} ${monthShort(total.start)}`;
  return monthShort(total.start);
}

export function SpendingChart({
  data,
  weekly,
  selected,
  onSelect,
}: {
  data: PeriodTotal[];
  weekly: boolean;
  selected: number | null;
  onSelect: (index: number) => void;
}) {
  const height = 220;
  const max = niceMax(data.map((d) => d.amount));
  const barArea = 44; // bar column width in the viewBox

  const width = data.length * barArea;
  const chartH = height - 26; // label strip
  const barW = Math.min(28, barArea - 12);

  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: "100%", height: "auto", display: "block" }} role="img">
      {[0.25, 0.5, 0.75, 1].map((f) => (
        <text
          key={f}
          x={2}
          y={chartH * (1 - f) - 2}
          fontSize="10"
          fill="var(--label-3)"
          className="num"
        >
          {axisLabel(max * f)}
        </text>
      ))}
      {data.map((d, i) => {
        const h = Math.max(2, (d.amount / max) * chartH);
        const x = i * barArea + (barArea - barW) / 2;
        const y = chartH - h;
        const isSel = selected === i;
        const fill = isSel
          ? "var(--accent)"
          : d.isForecast
            ? "color-mix(in srgb, var(--accent) 22%, transparent)"
            : "color-mix(in srgb, var(--accent) 50%, transparent)";
        return (
          <g key={d.start.getTime()} onClick={() => onSelect(i)} style={{ cursor: "pointer" }}>
            {/* tap target */}
            <rect x={i * barArea} y={0} width={barArea} height={chartH + 24} fill="transparent" />
            <rect x={x} y={y} width={barW} height={h} rx={6} fill={fill} />
            <text
              x={i * barArea + barArea / 2}
              y={height - 8}
              fontSize="10"
              textAnchor="middle"
              fill={isSel ? "var(--label)" : "var(--label-3)"}
              fontWeight={isSel ? 600 : 400}
            >
              {barLabel(d, weekly)}
            </text>
          </g>
        );
      })}
      <line x1={0} y1={chartH} x2={width} y2={chartH} stroke="var(--divider)" strokeWidth={0.5} />
    </svg>
  );
}

export function selectedCaption(total: PeriodTotal, weekly: boolean): string {
  const label = weekly
    ? `неделя ${total.start.getDate()} ${monthShort(total.start).toLowerCase()}`
    : monthNameCap(total.start);
  return `${label} · ${total.isForecast ? "прогноз" : "сейчас"}`;
}

import { monthName } from "@/lib/format";
function monthNameCap(d: Date): string {
  return monthName(d);
}

export function selectedAmount(total: PeriodTotal): string {
  return rub(total.amount);
}
