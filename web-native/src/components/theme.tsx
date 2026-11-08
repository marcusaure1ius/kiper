"use client";

// Theme + palette state. The boot script in layout.tsx already applied the
// stored values before paint; this provider keeps them in sync with React.

import { createContext, useContext, useEffect, useState } from "react";
import { accentHex, hex, PaletteKey } from "@/lib/palette";

export type ThemeMode = "auto" | "light" | "dark";

interface ThemeContextValue {
  mode: ThemeMode;
  palette: PaletteKey;
  dark: boolean;
  setMode: (mode: ThemeMode) => void;
  setPalette: (palette: PaletteKey) => void;
}

const ThemeContext = createContext<ThemeContextValue>({
  mode: "auto",
  palette: "lavender",
  dark: false,
  setMode: () => {},
  setPalette: () => {},
});

const THEME_KEY = "kiper.theme";
const PALETTE_KEY = "kiper.palette";

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [mode, setModeState] = useState<ThemeMode>("auto");
  const [palette, setPaletteState] = useState<PaletteKey>("lavender");
  const [dark, setDark] = useState(false);

  useEffect(() => {
    const storedMode = window.localStorage.getItem(THEME_KEY) as ThemeMode | null;
    const storedPalette = window.localStorage.getItem(PALETTE_KEY) as PaletteKey | null;
    if (storedMode === "auto" || storedMode === "light" || storedMode === "dark") setModeState(storedMode);
    if (storedPalette) setPaletteState(storedPalette);
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const apply = () => {
      const isDark = mode === "dark" || (mode === "auto" && mq.matches);
      root.classList.toggle("dark", isDark);
      root.style.setProperty("--accent", hex(accentHex(palette, isDark)));
      setDark(isDark);
    };
    apply();
    mq.addEventListener("change", apply);
    return () => mq.removeEventListener("change", apply);
  }, [mode, palette]);

  const value: ThemeContextValue = {
    mode,
    palette,
    dark,
    setMode: (m) => {
      setModeState(m);
      try { window.localStorage.setItem(THEME_KEY, m); } catch {}
    },
    setPalette: (p) => {
      setPaletteState(p);
      try { window.localStorage.setItem(PALETTE_KEY, p); } catch {}
    },
  };

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  return useContext(ThemeContext);
}
