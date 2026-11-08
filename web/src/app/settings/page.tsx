"use client";

// SettingsScreen.swift — appearance (theme + palettes), budget, categories,
// exchange rates (CBR), data (JSON/CSV/ICS export, import, reset), version.

import { useRef, useState } from "react";
import { CloudArrowUp, DownloadSimple, Plus, Table, Trash, UploadSimple } from "@phosphor-icons/react";
import { BackupError, decodeBackup, encodeCSV } from "@/lib/backup";
import { rub, fullDate } from "@/lib/format";
import { paletteTitle, PALETTES } from "@/lib/palette";
import { exportJSON, futurePayments, useKiper } from "@/lib/store";
import { useUI } from "@/lib/ui";
import { icsCalendar } from "@/lib/ics";
import { MeshPreview } from "@/components/AmbientBackground";
import { Sym } from "@/components/Sym";
import { Segmented, Sheet } from "@/components/ui";
import { useTheme, ThemeMode } from "@/components/theme";

function download(filename: string, text: string, mime: string): void {
  const blob = new Blob([text], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export default function SettingsPage() {
  const theme = useTheme();
  const budget = useKiper((s) => s.monthlyBudgetRub);
  const setBudget = useKiper((s) => s.setBudget);
  const categories = useKiper((s) => s.categories);
  const subs = useKiper((s) => s.subscriptions);
  const rate = useKiper((s) => s.rateSnapshot);
  const refreshing = useKiper((s) => s.refreshingRates);
  const refreshRates = useKiper((s) => s.refreshRates);
  const resetAll = useKiper((s) => s.resetAll);
  const importBackup = useKiper((s) => s.importBackup);
  const importCSV = useKiper((s) => s.importCSV);
  const show = useKiper((s) => s.show);
  const loadError = useKiper((s) => s.loadError);
  const openCategoryEditor = useUI((s) => s.openCategoryEditor);

  const [budgetText, setBudgetText] = useState(budget != null ? String(budget) : "");
  const [importText, setImportText] = useState<string | null>(null);
  const [importKind, setImportKind] = useState<"json" | "csv">("json");
  const [confirmReset, setConfirmReset] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const catCount = (id: string) => subs.filter((s) => s.categoryId === id && s.status !== "cancelled").length;

  function exportICS(): void {
    const events = futurePayments({ subscriptions: subs }, 365);
    download("kiper.ics", icsCalendar(events), "text/calendar");
  }

  function onFilePicked(file: File): void {
    void file.text().then((text) => {
      if (file.name.toLowerCase().endsWith(".csv")) {
        const result = importCSV(text);
        show(result.subscriptions > 0 ? "Подписки импортированы" : "Не удалось прочитать CSV", undefined, result.subscriptions > 0 ? "green" : "orange");
      } else {
        try {
          decodeBackup(text);
          setImportText(text);
          setImportKind("json");
        } catch (error) {
          const message = error instanceof BackupError ? error.message : "Не удалось прочитать файл";
          show(message, "exclamationmark.triangle.fill", "orange");
        }
      }
    });
  }

  return (
    <div className="page screen-pad" style={{ paddingTop: 8, maxWidth: 760 }}>
      <h1 className="t-title" style={{ margin: "6px 4px 16px" }}>
        Настройки
      </h1>

      {loadError && (
        <div className="card" style={{ borderColor: "rgba(255,159,10,0.4)", marginBottom: 16 }}>
          <div className="t-footnote" style={{ color: "#ff9f0a", fontWeight: 600 }}>
            Не удалось прочитать сохранённые данные. Копия сохранена в «kiper.quarantine.v1».
          </div>
        </div>
      )}

      <div className="section-label">Внешний вид</div>
      <div className="inset-list">
        <div className="inset-row">
          <span className="t-body">Тема</span>
          <div style={{ marginLeft: "auto", width: 220 }}>
            <Segmented
              options={[
                { value: "auto", label: "Авто" },
                { value: "light", label: "Светлая" },
                { value: "dark", label: "Тёмная" },
              ]}
              value={theme.mode}
              onChange={(m: ThemeMode) => theme.setMode(m)}
            />
          </div>
        </div>
        <div className="inset-row" style={{ alignItems: "flex-start", flexDirection: "column", gap: 10, paddingBlock: 14 }}>
          <span className="t-body">Цвета</span>
          {/* запас по всем сторонам: кольцо выбранной плитки (5,5px) не должно срезаться скроллом */}
          <div className="scroll-x" style={{ width: "100%", padding: "8px 10px 12px" }}>
            {PALETTES.map((p) => {
              const on = theme.palette === p;
              return (
                <button key={p} className="tap-scale" style={{ flex: "none", display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }} onClick={() => theme.setPalette(p)}>
                  <MeshPreview
                    palette={p}
                    dark={theme.dark}
                    className={on ? "palette-tile on" : "palette-tile"}
                  />
                  <span className="t-caption2" style={{ color: on ? "var(--accent)" : "var(--label-2)", fontWeight: 600 }}>
                    {paletteTitle[p]}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      <div className="section-label">Бюджет</div>
      <div className="inset-list">
        <div className="inset-row">
          <span className="t-body secondary" style={{ flex: "none" }}>
            Лимит, ₽ в месяц
          </span>
          <input
            className="field num"
            style={{ maxWidth: 140, marginLeft: "auto", textAlign: "right" }}
            placeholder="Не задан"
            inputMode="decimal"
            value={budgetText}
            onChange={(e) => setBudgetText(e.target.value)}
            onBlur={() => {
              const parsed = Number.parseFloat(budgetText.replace(/\s/g, "").replace(",", "."));
              setBudget(Number.isNaN(parsed) ? null : parsed);
            }}
          />
        </div>
      </div>

      <div className="section-label">Категории</div>
      <div className="inset-list">
        {categories.map((c) => (
          <button key={c.id} className="inset-row" style={{ width: "100%", textAlign: "left" }} onClick={() => openCategoryEditor(c.id)}>
            <span style={{ color: `#${c.colorHex.toString(16).padStart(6, "0")}`, display: "flex" }}>
              <Sym name={c.symbol} size={19} />
            </span>
            <span className="t-body" style={{ fontWeight: 500, flex: 1 }}>
              {c.name}
            </span>
            <span className="t-subheadline secondary num">{catCount(c.id)}</span>
          </button>
        ))}
        <button className="inset-row" style={{ width: "100%", textAlign: "left" }} onClick={() => openCategoryEditor(null)}>
          <span style={{ color: "var(--accent)", display: "flex" }}>
            <Plus size={19} weight="bold" />
          </span>
          <span className="t-body" style={{ fontWeight: 500, color: "var(--accent)" }}>
            Добавить категорию
          </span>
        </button>
      </div>

      <div className="section-label">Курсы валют</div>
      <div className="inset-list">
        <div className="inset-row">
          <span className="t-body">1 USD</span>
          <span className="t-body num" style={{ marginLeft: "auto" }}>
            {rub(rate.usd)}
          </span>
        </div>
        <div className="inset-row">
          <span className="t-body">1 EUR</span>
          <span className="t-body num" style={{ marginLeft: "auto" }}>
            {rub(rate.eur)}
          </span>
        </div>
        <button className="inset-row" style={{ width: "100%", textAlign: "left" }} onClick={() => void refreshRates()} disabled={refreshing}>
          <span style={{ color: "var(--accent)", display: "flex" }}>
            <CloudArrowUp size={19} />
          </span>
          <span className="t-body" style={{ fontWeight: 500, color: "var(--accent)" }}>
            {refreshing ? "Обновление…" : "Обновить курсы"}
          </span>
        </button>
        <div className="inset-row">
          <span className="t-caption secondary">Курс ЦБ РФ · сохранено {fullDate(rate.fetchedAt)}</span>
        </div>
      </div>

      <div className="section-label">Данные</div>
      <div className="inset-list">
        <button className="inset-row" style={{ width: "100%", textAlign: "left" }} onClick={() => download("kiper-backup.json", exportJSON(useKiper.getState()), "application/json")}>
          <span style={{ color: "var(--accent)", display: "flex" }}>
            <UploadSimple size={19} />
          </span>
          <span className="t-body" style={{ fontWeight: 500, color: "var(--accent)" }}>
            Экспорт в JSON
          </span>
        </button>
        <button
          className="inset-row"
          style={{ width: "100%", textAlign: "left" }}
          onClick={() => download("kiper.csv", encodeCSV(useKiper.getState().subscriptions), "text/csv")}
        >
          <span style={{ color: "var(--accent)", display: "flex" }}>
            <Table size={19} />
          </span>
          <span className="t-body" style={{ fontWeight: 500, color: "var(--accent)" }}>
            Экспорт в CSV
          </span>
        </button>
        <button className="inset-row" style={{ width: "100%", textAlign: "left" }} onClick={exportICS}>
          <span style={{ color: "var(--accent)", display: "flex" }}>
            <DownloadSimple size={19} />
          </span>
          <span className="t-body" style={{ fontWeight: 500, color: "var(--accent)" }}>
            Экспорт в Календарь (.ics)
          </span>
        </button>
        <button className="inset-row" style={{ width: "100%", textAlign: "left" }} onClick={() => fileRef.current?.click()}>
          <span style={{ color: "var(--accent)", display: "flex" }}>
            <DownloadSimple size={19} />
          </span>
          <span className="t-body" style={{ fontWeight: 500, color: "var(--accent)" }}>
            Импорт из файла
          </span>
        </button>
        <input
          ref={fileRef}
          type="file"
          accept=".json,.csv,text/csv,application/json"
          style={{ display: "none" }}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) onFilePicked(file);
            e.target.value = "";
          }}
        />
        <button className="inset-row" style={{ width: "100%", textAlign: "left" }} onClick={() => setConfirmReset(true)}>
          <span style={{ color: "#ff453a", display: "flex" }}>
            <Trash size={19} />
          </span>
          <span className="t-body" style={{ fontWeight: 500, color: "#ff453a" }}>
            Удалить все данные
          </span>
        </button>
      </div>

      <div className="t-caption tertiary" style={{ textAlign: "center", padding: "18px 0 8px" }}>
        Кипер для веб · Версия 1.0.0
      </div>

      <Sheet open={importText != null} onClose={() => setImportText(null)} title="Импорт" detent="half">
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <div className="t-subheadline secondary" style={{ padding: "4px 2px" }}>
            Заменить текущие данные или объединить с ними?
          </div>
          <button
            className="btn-prominent"
            onClick={() => {
              const result = importBackup(decodeBackup(importText!), "replace");
              setImportText(null);
              show(`Импортировано: ${result.subscriptions} подписка(и), ${result.categories} категория(и)`);
            }}
          >
            Заменить
          </button>
          <button
            className="btn-glass"
            onClick={() => {
              const result = importBackup(decodeBackup(importText!), "merge");
              setImportText(null);
              show(`Импортировано: ${result.subscriptions} подписка(и), ${result.categories} категория(и)`);
            }}
          >
            Объединить
          </button>
          <button className="btn-glass" onClick={() => setImportText(null)}>
            Отмена
          </button>
        </div>
      </Sheet>

      <Sheet open={confirmReset} onClose={() => setConfirmReset(false)} title="Удалить все данные?" detent="half">
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <div className="t-subheadline secondary" style={{ padding: "4px 2px" }}>
            Подписки и история платежей будут удалены. Категории вернутся к стандартным.
          </div>
          <button
            className="btn-prominent"
            style={{ background: "color-mix(in srgb, #ff453a 78%, transparent)" }}
            onClick={() => {
              resetAll();
              setConfirmReset(false);
              show("Все данные удалены", "trash", "red");
            }}
          >
            Удалить
          </button>
          <button className="btn-glass" onClick={() => setConfirmReset(false)}>
            Отмена
          </button>
        </div>
      </Sheet>
    </div>
  );
}
