// Port of ios-native/Kiper/Shared/Background.swift — six background palettes.
// The palette's accent becomes the app-wide tint; the 3×3 mesh colors are the
// animated background.

export const PALETTES = ["lavender", "aurora", "sunset", "ocean", "graphite", "iris"] as const;
export type PaletteKey = (typeof PALETTES)[number];

export const paletteTitle: Record<PaletteKey, string> = {
  lavender: "Лаванда",
  aurora: "Аврора",
  sunset: "Закат",
  ocean: "Океан",
  graphite: "Графит",
  iris: "Ирис",
};

/// Raw accent as 0xRRGGBB (light / dark).
export function accentHex(style: PaletteKey, dark: boolean): number {
  switch (style) {
    case "lavender": return dark ? 0x8F84FF : 0x6A5CF1;
    case "aurora": return dark ? 0x3DD9A8 : 0x0E9F7E;
    case "sunset": return dark ? 0xFF8A65 : 0xE8553A;
    case "ocean": return dark ? 0x4FB0FF : 0x1E7FD9;
    case "graphite": return dark ? 0xC7CBD3 : 0x4A505C;
    case "iris": return dark ? 0xFF6FB5 : 0xD13F8A;
  }
}

/// 3×3 mesh colors, row by row (0xRRGGBB).
export function meshColors(style: PaletteKey, dark: boolean): number[] {
  switch (style) {
    case "lavender":
      return dark
        ? [0x2A1B5E, 0x1E1648, 0x14204A, 0x170F33, 0x4A2B9A, 0x16224F, 0x0B0818, 0x120C26, 0x0A0D1C]
        : [0xDCD6FF, 0xF3E8FF, 0xD3ECFF, 0xF7F5FF, 0xE6DCFF, 0xFFE9DD, 0xFBF9F6, 0xF6F4FA, 0xFBF9F6];
    case "aurora":
      return dark
        ? [0x06302F, 0x0A2238, 0x1A1446, 0x05221F, 0x12805F, 0x2A1C66, 0x030B0C, 0x061A18, 0x0A0820]
        : [0xCFF5E7, 0xD8E9FF, 0xE9DDFF, 0xE6FFF5, 0xB8F0DC, 0xDCD3FF, 0xF7FBFA, 0xEAF7F3, 0xF6F4FF];
    case "sunset":
      return dark
        ? [0x3B1030, 0x4A1A2A, 0x2A1240, 0x240A1C, 0x8A3048, 0x3A1650, 0x0E050C, 0x1C0812, 0x100616]
        : [0xFFD9C7, 0xFFE3D3, 0xFFD0E0, 0xFFF0E5, 0xFFC9B0, 0xFFDCEA, 0xFFF8F2, 0xFFEFE6, 0xFDF3F7];
    case "ocean":
      return dark
        ? [0x0A2350, 0x0C3566, 0x07384A, 0x061633, 0x1460A8, 0x087060, 0x020A18, 0x04142A, 0x021614]
        : [0xCDE8FF, 0xD5F3FF, 0xCFF7EE, 0xEAF6FF, 0xB9E2FF, 0xD7FBF2, 0xF6FAFD, 0xEDF7FB, 0xF4FBF9];
    case "graphite":
      return dark
        ? [0x26262B, 0x2C2C31, 0x222328, 0x18181B, 0x34343A, 0x1D1E22, 0x0A0A0B, 0x111113, 0x0C0C0D]
        : [0xEDEDF0, 0xF4F4F6, 0xE8EAEE, 0xF7F7F8, 0xE4E4E8, 0xEFEFF2, 0xFAFAFA, 0xF3F3F5, 0xF8F8F9];
    case "iris":
      return dark
        ? [0x3B1F86, 0x7A2450, 0x10407A, 0x6A1838, 0x161226, 0x0D5240, 0x0E4B5A, 0x231A5E, 0x5A1640]
        : [0xE3D6FF, 0xFFE0D1, 0xD2E9FF, 0xFFD6DE, 0xF5F0FF, 0xD9F7E3, 0xFFF1C9, 0xE0DBFF, 0xFFDDEB];
  }
}

export function hex(n: number): string {
  return `#${n.toString(16).padStart(6, "0")}`;
}

export function rgba(n: number, alpha: number): string {
  const r = (n >> 16) & 0xFF, g = (n >> 8) & 0xFF, b = n & 0xFF;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

export const paperHex = 0xFBF9F6; // brand paper-white anchor
