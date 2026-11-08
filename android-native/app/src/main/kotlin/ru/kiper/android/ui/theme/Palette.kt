package ru.kiper.android.ui.theme

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/** Background palettes — exact port of `BackgroundStyle` from `Background.swift`. */
enum class BackgroundStyle(val title: String) {
    LAVENDER("Лаванда"),
    AURORA("Аврора"),
    SUNSET("Закат"),
    OCEAN("Океан"),
    GRAPHITE("Графит"),
    IRIS("Ирис");

    /** Accent for controls, selections and charts — tuned per palette and theme. */
    fun accent(dark: Boolean): Color = Color(accentHex(dark).let { 0xFF000000L or it.toLong() }.toInt())

    /** Raw accent as 0xRRGGBB (shared with widgets). */
    fun accentHex(dark: Boolean): Int = when (this) {
        LAVENDER -> if (dark) 0x8F84FF else 0x6A5CF1
        AURORA -> if (dark) 0x3DD9A8 else 0x0E9F7E
        SUNSET -> if (dark) 0xFF8A65 else 0xE8553A
        OCEAN -> if (dark) 0x4FB0FF else 0x1E7FD9
        GRAPHITE -> if (dark) 0xC7CBD3 else 0x4A505C
        IRIS -> if (dark) 0xFF6FB5 else 0xD13F8A
    }

    /** 3×3 mesh colours, row by row. */
    fun colors(dark: Boolean): List<Int> = when (this) {
        LAVENDER -> if (dark) listOf(
            0x2A1B5E, 0x1E1648, 0x14204A, 0x170F33, 0x4A2B9A, 0x16224F, 0x0B0818, 0x120C26, 0x0A0D1C
        ) else listOf(
            0xDCD6FF, 0xF3E8FF, 0xD3ECFF, 0xF7F5FF, 0xE6DCFF, 0xFFE9DD, 0xFBF9F6, 0xF6F4FA, 0xFBF9F6
        )
        AURORA -> if (dark) listOf(
            0x06302F, 0x0A2238, 0x1A1446, 0x05221F, 0x12805F, 0x2A1C66, 0x030B0C, 0x061A18, 0x0A0820
        ) else listOf(
            0xCFF5E7, 0xD8E9FF, 0xE9DDFF, 0xE6FFF5, 0xB8F0DC, 0xDCD3FF, 0xF7FBFA, 0xEAF7F3, 0xF6F4FF
        )
        SUNSET -> if (dark) listOf(
            0x3B1030, 0x4A1A2A, 0x2A1240, 0x240A1C, 0x8A3048, 0x3A1650, 0x0E050C, 0x1C0812, 0x100616
        ) else listOf(
            0xFFD9C7, 0xFFE3D3, 0xFFD0E0, 0xFFF0E5, 0xFFC9B0, 0xFFDCEA, 0xFFF8F2, 0xFFEFE6, 0xFDF3F7
        )
        OCEAN -> if (dark) listOf(
            0x0A2350, 0x0C3566, 0x07384A, 0x061633, 0x1460A8, 0x087060, 0x020A18, 0x04142A, 0x021614
        ) else listOf(
            0xCDE8FF, 0xD5F3FF, 0xCFF7EE, 0xEAF6FF, 0xB9E2FF, 0xD7FBF2, 0xF6FAFD, 0xEDF7FB, 0xF4FBF9
        )
        GRAPHITE -> if (dark) listOf(
            0x26262B, 0x2C2C31, 0x222328, 0x18181B, 0x34343A, 0x1D1E22, 0x0A0A0B, 0x111113, 0x0C0C0D
        ) else listOf(
            0xEDEDF0, 0xF4F4F6, 0xE8EAEE, 0xF7F7F8, 0xE4E4E8, 0xEFEFF2, 0xFAFAFA, 0xF3F3F5, 0xF8F8F9
        )
        IRIS -> if (dark) listOf(
            0x3B1F86, 0x7A2450, 0x10407A, 0x6A1838, 0x161226, 0x0D5240, 0x0E4B5A, 0x231A5E, 0x5A1640
        ) else listOf(
            0xE3D6FF, 0xFFE0D1, 0xD2E9FF, 0xFFD6DE, 0xF5F0FF, 0xD9F7E3, 0xFFF1C9, 0xE0DBFF, 0xFFDDEB
        )
    }

    companion object {
        fun of(raw: String?): BackgroundStyle = entries.firstOrNull { it.name == raw || it.name.lowercase() == raw?.lowercase() } ?: LAVENDER
    }
}

fun colorHex(hex: Int): Color = Color(0xFF000000L or (hex.toLong() and 0xFFFFFF))

/** App accent derived from the chosen palette. */
val LocalAppAccent = staticCompositionLocalOf { Color(0xFF685CF1) }
