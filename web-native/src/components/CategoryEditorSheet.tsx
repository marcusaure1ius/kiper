"use client";

// CategoryEditorSheet.swift — live preview tile, name, 12-color grid,
// 30-symbol grid, destructive delete in edit mode.

import { useMemo, useState } from "react";
import { Trash } from "@phosphor-icons/react";
import { editorColors, editorSymbols } from "@/lib/catalog";
import { Category } from "@/lib/models";
import { rgba } from "@/lib/palette";
import { useKiper } from "@/lib/store";
import { useUI } from "@/lib/ui";
import { Sym } from "./Sym";
import { Sheet } from "./ui";

export function CategoryEditorSheet() {
  const editorId = useUI((s) => s.categoryEditorId);
  const editorOpen = useUI((s) => s.categoryEditorOpen);
  const close = useUI((s) => s.closeCategoryEditor);
  const categories = useKiper((s) => s.categories);
  const upsertCategory = useKiper((s) => s.upsertCategory);
  const deleteCategory = useKiper((s) => s.deleteCategory);
  const show = useKiper((s) => s.show);

  const existing = useMemo(() => categories.find((c) => c.id === editorId) ?? null, [categories, editorId]);
  const [name, setName] = useState<string | null>(null);
  const [colorHex, setColorHex] = useState<number | null>(null);
  const [symbol, setSymbol] = useState<string | null>(null);

  const draft: Category = {
    id: existing?.id ?? crypto.randomUUID(),
    name: name ?? existing?.name ?? "",
    colorHex: colorHex ?? existing?.colorHex ?? editorColors[0],
    symbol: symbol ?? existing?.symbol ?? editorSymbols[0],
  };
  const valid = draft.name.trim().length > 0;
  const isEdit = existing != null;

  function save() {
    if (!valid) return;
    upsertCategory({ ...draft, name: draft.name.trim() });
    show(isEdit ? "Категория обновлена" : "Категория добавлена");
    setName(null);
    setColorHex(null);
    setSymbol(null);
    close();
  }

  return (
    <Sheet
      open={editorOpen}
      onClose={() => {
        setName(null);
        setColorHex(null);
        setSymbol(null);
        close();
      }}
      title={isEdit ? "Категория" : "Новая категория"}
      detent="half"
      trailing={
        <button className="nav-title" style={{ color: valid ? "var(--accent)" : "var(--label-3)" }} onClick={save} disabled={!valid}>
          Готово
        </button>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 16, paddingBottom: 12 }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10, padding: "10px 0 4px" }}>
          <div
            style={{
              width: 76,
              height: 76,
              borderRadius: 22,
              background: `linear-gradient(160deg, ${rgba(draft.colorHex, 0.9)}, ${rgba(draft.colorHex, 0.65)})`,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              color: "#fff",
            }}
          >
            <Sym name={draft.symbol} size={38} />
          </div>
          <span
            className="chip"
            style={{ background: `color-mix(in srgb, ${rgba(draft.colorHex, 0.7)}, transparent)`, color: "#fff", borderColor: "transparent" }}
          >
            <Sym name={draft.symbol} size={14} />
            {draft.name || "Категория"}
          </span>
        </div>

        <div className="inset-list">
          <div className="inset-row" style={{ padding: 4 }}>
            <input
              className="field"
              placeholder="Например, Обучение"
              value={draft.name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>
        </div>

        <div>
          <div className="section-label" style={{ margin: "0 4px 8px" }}>
            Цвет
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: 14, justifyItems: "center" }}>
            {editorColors.map((c) => {
              const on = draft.colorHex === c;
              return (
                <button
                  key={c}
                  aria-label={`Цвет ${c.toString(16)}`}
                  onClick={() => setColorHex(c)}
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: 18,
                    background: `#${c.toString(16).padStart(6, "0")}`,
                    boxShadow: on ? `0 0 0 2px var(--paper, #fbf9f6), 0 0 0 4px #${c.toString(16).padStart(6, "0")}` : "none",
                    transform: on ? "scale(0.94)" : "none",
                    transition: "box-shadow 0.15s ease, transform 0.15s ease",
                  }}
                />
              );
            })}
          </div>
        </div>

        <div>
          <div className="section-label" style={{ margin: "0 4px 8px" }}>
            Иконка
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: 12, justifyItems: "center" }}>
            {editorSymbols.map((s) => {
              const on = draft.symbol === s;
              return (
                <button
                  key={s}
                  aria-label={s}
                  onClick={() => setSymbol(s)}
                  style={{
                    width: 42,
                    height: 42,
                    borderRadius: 12,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    background: on ? `#${draft.colorHex.toString(16).padStart(6, "0")}` : rgba(draft.colorHex, 0.12),
                    color: on ? "#fff" : `#${draft.colorHex.toString(16).padStart(6, "0")}`,
                    transition: "background 0.15s ease, color 0.15s ease",
                  }}
                >
                  <Sym name={s} size={20} />
                </button>
              );
            })}
          </div>
        </div>

        {isEdit && (
          <button
            className="btn-glass"
            style={{ color: "#ff453a", minHeight: 44 }}
            onClick={() => {
              deleteCategory(existing.id);
              show("Категория удалена", "trash", "red");
              setName(null);
              setColorHex(null);
              setSymbol(null);
              close();
            }}
          >
            <Trash size={17} weight="fill" />
            Удалить категорию
          </button>
        )}
      </div>
    </Sheet>
  );
}
