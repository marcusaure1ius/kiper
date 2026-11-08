"use client";

// Port of FlowingBackdrop (Shared/Background.swift): nine mesh blobs warped
// sinusoidally on a rAF timeline, blurred and over-saturated like the iOS
// MeshGradient (saturation 1.25, scale 1.35, blur 36 → web equivalents).

import { useEffect, useRef } from "react";
import { meshColors, PaletteKey } from "@/lib/palette";
import { useTheme } from "./theme";

const BASE: [number, number][] = [
  [0, 0], [0.5, 0], [1, 0],
  [0, 0.5], [0.6, 0.4], [1, 0.5],
  [0, 1], [0.5, 1], [1, 1],
];

function warp(speed: number, phase: number, amp: number, t: number): number {
  return Math.sin(t * speed + phase) * amp;
}

function points(t: number): [number, number][] {
  return [
    [0, 0],
    [0.5 + warp(0.55, 0, 0.3, t), 0],
    [1, 0],
    [0, 0.5 + warp(0.45, 1.3, 0.3, t)],
    [0.5 + warp(0.6, 2.1, 0.32, t), 0.5 + warp(0.5, 0.4, 0.32, t)],
    [1, 0.5 + warp(0.4, 3.7, 0.3, t)],
    [0, 1],
    [0.5 + warp(0.5, 5.2, 0.3, t), 1],
    [1, 1],
  ];
}

export function AmbientBackground() {
  const { palette, dark } = useTheme();
  const refs = useRef<(HTMLDivElement | null)[]>([]);
  const colors = meshColors(palette, dark);

  useEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced) return;
    let raf = 0;
    const tick = (ms: number) => {
      const t = ms / 1000;
      const pts = points(t);
      pts.forEach(([x, y], i) => {
        const el = refs.current[i];
        if (el) {
          el.style.left = `${x * 100}%`;
          el.style.top = `${y * 100}%`;
        }
      });
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    const onVis = () => {
      if (document.hidden) {
        cancelAnimationFrame(raf);
        raf = 0;
      } else if (!raf) {
        raf = requestAnimationFrame(tick);
      }
    };
    document.addEventListener("visibilitychange", onVis);
    return () => {
      cancelAnimationFrame(raf);
      document.removeEventListener("visibilitychange", onVis);
    };
  }, []);

  return (
    <div
      aria-hidden
      style={{
        position: "fixed",
        inset: 0,
        zIndex: -1,
        overflow: "hidden",
        pointerEvents: "none",
        filter: "blur(60px) saturate(1.25)",
        transform: "scale(1.35)",
        background: `#${colors[6].toString(16).padStart(6, "0")}`,
      }}
    >
      {BASE.map((_, i) => (
        <div
          key={i}
          ref={(el) => {
            refs.current[i] = el;
          }}
          style={{
            position: "absolute",
            left: `${BASE[i][0] * 100}%`,
            top: `${BASE[i][1] * 100}%`,
            width: "72vmax",
            height: "72vmax",
            marginLeft: "-36vmax",
            marginTop: "-36vmax",
            borderRadius: "50%",
            background: `radial-gradient(circle, #${colors[i].toString(16).padStart(6, "0")} 0%, transparent 68%)`,
            opacity: 0.9,
            willChange: "left, top",
          }}
        />
      ))}
    </div>
  );
}

/// Static mini mesh for palette previews (Settings → TilePicker).
export function MeshPreview({ palette, dark, className }: { palette: PaletteKey; dark: boolean; className?: string }) {
  const colors = meshColors(palette, dark);
  return (
    <div
      className={className}
      style={{
        position: "relative",
        overflow: "hidden",
        background: `#${colors[4].toString(16).padStart(6, "0")}`,
      }}
      aria-hidden
    >
      {BASE.map((p, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: `${p[0] * 100}%`,
            top: `${p[1] * 100}%`,
            width: "150%",
            height: "150%",
            transform: "translate(-50%, -50%)",
            borderRadius: "50%",
            background: `radial-gradient(circle, #${colors[i].toString(16).padStart(6, "0")} 0%, transparent 62%)`,
          }}
        />
      ))}
    </div>
  );
}
