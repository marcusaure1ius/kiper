"use client";

// AddSubscriptionFlow.swift — catalog picker sheet (search + groups) feeding
// the pre-filled form; «Своя подписка» starts an empty form.

import { useMemo, useState } from "react";
import { MagnifyingGlass, NotePencil, PlusCircle, X } from "@phosphor-icons/react";
import { catalog, catalogGroups, CatalogEntry } from "@/lib/catalog";
import { currencySymbol } from "@/lib/models";
import { SubscriptionLogo } from "./SubscriptionViews";
import { useUI } from "@/lib/ui";
import { SubscriptionForm } from "./SubscriptionForm";
import { Sheet } from "./ui";

export function AddSheet() {
  const open = useUI((s) => s.addOpen);
  const step = useUI((s) => s.addStep);
  const preset = useUI((s) => s.addPreset);
  const close = useUI((s) => s.closeAdd);
  const openForm = useUI((s) => s.openAddForm);
  const backToCatalog = useUI((s) => s.backToAddCatalog);

  const [query, setQuery] = useState("");
  const q = query.trim().toLowerCase();

  const groups = useMemo(
    () =>
      catalogGroups
        .map((g) => ({ ...g, entries: catalog.filter((e) => e.categoryId === g.id && (!q || e.name.toLowerCase().includes(q))) }))
        .filter((g) => g.entries.length > 0),
    [q],
  );

  return (
    <Sheet
      open={open}
      onClose={close}
      title={step === "catalog" ? "Новая подписка" : "Новая подписка"}
      detent="full"
      trailing={
        step === "form" ? (
          <button className="nav-title" style={{ color: "var(--accent)" }} onClick={backToCatalog}>
            Назад
          </button>
        ) : undefined
      }
    >
      {step === "catalog" ? (
        <CatalogList
          query={query}
          setQuery={setQuery}
          groups={groups}
          onPick={(entry) => openForm({ entry, amount: undefined })}
          onCustom={() => openForm({})}
          onCreateFromQuery={() => openForm({ name: query.trim(), query: query.trim() })}
        />
      ) : (
        <SubscriptionForm preset={preset} onDone={close} />
      )}
    </Sheet>
  );
}

function CatalogList({
  query,
  setQuery,
  groups,
  onPick,
  onCustom,
  onCreateFromQuery,
}: {
  query: string;
  setQuery: (v: string) => void;
  groups: { id: string; name: string; entries: CatalogEntry[] }[];
  onPick: (entry: CatalogEntry) => void;
  onCustom: () => void;
  onCreateFromQuery: () => void;
}) {
  const q = query.trim();
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <div style={{ position: "relative" }}>
        <span style={{ position: "absolute", left: 12, top: 13, color: "var(--label-3)", display: "flex" }}>
          <MagnifyingGlass size={16} />
        </span>
        <input
          className="field"
          style={{ paddingLeft: 36, paddingRight: 36 }}
          placeholder="Название сервиса"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        {query && (
          <button
            aria-label="Очистить"
            onClick={() => setQuery("")}
            style={{ position: "absolute", right: 10, top: 11, color: "var(--label-3)", display: "flex" }}
          >
            <X size={14} weight="bold" />
          </button>
        )}
      </div>

      <div className="inset-list">
        {q ? (
          <CatalogActionRow symbol="plus.circle.fill" tint="var(--accent)" label={`Создать «${q}»`} onClick={onCreateFromQuery} />
        ) : (
          <CatalogActionRow symbol="square.and.pencil" tint="var(--accent)" label="Своя подписка" onClick={onCustom} />
        )}
      </div>
      <div className="t-footnote secondary" style={{ padding: "0 4px" }}>
        {q
          ? "Можно создать подписку с этим названием — остальное заполните сами."
          : "Или выберите сервис — название, валюта и период подставятся сами."}
      </div>

      {groups.map((g) => (
        <div key={g.id}>
          <div className="section-label" style={{ margin: "0 4px 8px" }}>
            {g.name}
          </div>
          <div className="inset-list">
            {g.entries.map((entry) => (
              <button key={entry.name} className="inset-row dent" style={{ width: "100%", textAlign: "left" }} onClick={() => onPick(entry)}>
                <SubscriptionLogo size={36} category={null} domain={entry.domain} />
                <span className="t-body" style={{ fontWeight: 500, flex: 1 }}>
                  {entry.name}
                </span>
                <span className="t-subheadline secondary">{currencySymbol[entry.currency]}</span>
              </button>
            ))}
          </div>
        </div>
      ))}

      {groups.length === 0 && q && (
        <div className="t-subheadline secondary" style={{ textAlign: "center", padding: "24px 0" }}>
          Сервис не найден
        </div>
      )}
    </div>
  );
}

function CatalogActionRow({ symbol, tint, label, onClick }: { symbol: string; tint: string; label: string; onClick: () => void }) {
  return (
    <button className="inset-row" style={{ width: "100%", textAlign: "left", gap: 12 }} onClick={onClick}>
      <span style={{ color: tint, display: "flex" }}>
        {symbol === "plus.circle.fill" ? <PlusCircle size={24} weight="fill" /> : <NotePencil size={24} />}
      </span>
      <span className="t-body" style={{ fontWeight: 500, color: "var(--accent)" }}>
        {label}
      </span>
    </button>
  );
}
