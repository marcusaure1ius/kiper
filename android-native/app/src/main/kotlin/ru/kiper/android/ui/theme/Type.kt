package ru.kiper.android.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * System font (Samsung One UI Sans / Roboto) — native to each device, with
 * weight and size tuning. No bundled font: devices know best how to render
 * their own type.
 */
val KiperFontFamily: FontFamily = FontFamily.Default

/** App typography: native font, slightly tighter display sizes. */
fun kiperTypography(): Typography {
    val base = Typography()
    return Typography(
        displayLarge = base.displayLarge.copy(fontFamily = KiperFontFamily),
        displayMedium = base.displayMedium.copy(fontFamily = KiperFontFamily),
        displaySmall = base.displaySmall.copy(fontFamily = KiperFontFamily),
        headlineLarge = base.headlineLarge.copy(fontFamily = KiperFontFamily, fontWeight = FontWeight.Bold, letterSpacing = (-0.3).sp),
        headlineMedium = base.headlineMedium.copy(fontFamily = KiperFontFamily, fontWeight = FontWeight.Bold, letterSpacing = (-0.3).sp),
        headlineSmall = base.headlineSmall.copy(fontFamily = KiperFontFamily, fontWeight = FontWeight.Bold),
        titleLarge = base.titleLarge.copy(fontFamily = KiperFontFamily, fontWeight = FontWeight.Bold, letterSpacing = (-0.2).sp),
        titleMedium = base.titleMedium.copy(fontFamily = KiperFontFamily, fontWeight = FontWeight.SemiBold, fontSize = 17.sp),
        titleSmall = base.titleSmall.copy(fontFamily = KiperFontFamily, fontWeight = FontWeight.SemiBold),
        bodyLarge = base.bodyLarge.copy(fontFamily = KiperFontFamily, fontSize = 16.sp),
        bodyMedium = base.bodyMedium.copy(fontFamily = KiperFontFamily, fontSize = 14.sp),
        bodySmall = base.bodySmall.copy(fontFamily = KiperFontFamily, fontSize = 12.sp),
        labelLarge = base.labelLarge.copy(fontFamily = KiperFontFamily, fontWeight = FontWeight.SemiBold),
        labelMedium = base.labelMedium.copy(fontFamily = KiperFontFamily, fontWeight = FontWeight.SemiBold),
        labelSmall = base.labelSmall.copy(fontFamily = KiperFontFamily, fontSize = 11.sp),
    )
}

/** Hero number — the biggest style (matches the 44pt bold on iOS). */
val HeroNumberStyle = TextStyle(
    fontFamily = KiperFontFamily,
    fontWeight = FontWeight.Bold,
    fontSize = 42.sp,
    letterSpacing = (-0.8).sp,
)
