// UI-level state: sheets, payments tab, form presets. Kept separate from the
// data store so persistence only tracks real data.

import { create } from "zustand";
import { CatalogEntry } from "./catalog";

export interface FormPreset {
  entry?: CatalogEntry;
  name?: string;
  amount?: number;
  query?: string;
}

interface UIState {
  paymentsOpen: boolean;
  paymentsTab: "history" | "upcoming";
  addOpen: boolean;
  addStep: "catalog" | "form";
  addPreset: FormPreset | null;
  editSubId: string | null;
  categoryEditorId: string | null; // null = new category
  categoryEditorOpen: boolean;
  detailUpcomingHidden: boolean;
  openPayments: (tab?: "history" | "upcoming") => void;
  closePayments: () => void;
  openAdd: (preset?: FormPreset) => void;
  openAddForm: (preset: FormPreset) => void;
  backToAddCatalog: () => void;
  closeAdd: () => void;
  openEdit: (id: string) => void;
  closeEdit: () => void;
  openCategoryEditor: (id: string | null) => void;
  closeCategoryEditor: () => void;
}

export const useUI = create<UIState>((set) => ({
  paymentsOpen: false,
  paymentsTab: "history",
  addOpen: false,
  addStep: "catalog",
  addPreset: null,
  editSubId: null,
  categoryEditorId: null,
  categoryEditorOpen: false,
  detailUpcomingHidden: false,
  openPayments: (tab) => set({ paymentsOpen: true, paymentsTab: tab ?? "history" }),
  closePayments: () => set({ paymentsOpen: false }),
  openAdd: (preset) => set({ addOpen: true, addStep: "catalog", addPreset: preset ?? null }),
  openAddForm: (preset) => set({ addOpen: true, addStep: "form", addPreset: preset }),
  backToAddCatalog: () => set({ addStep: "catalog" }),
  closeAdd: () => set({ addOpen: false, addStep: "catalog", addPreset: null }),
  openEdit: (id) => set({ editSubId: id }),
  closeEdit: () => set({ editSubId: null }),
  openCategoryEditor: (id) => set({ categoryEditorOpen: true, categoryEditorId: id }),
  closeCategoryEditor: () => set({ categoryEditorOpen: false, categoryEditorId: null }),
}));
