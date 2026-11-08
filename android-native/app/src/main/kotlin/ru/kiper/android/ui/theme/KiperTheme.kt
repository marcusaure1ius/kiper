package ru.kiper.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color

/** App theme: accent comes from the chosen palette, surfaces stay neutral like the
 * iOS `regularMaterial` cards on the flowing mesh. */
@Composable
fun KiperTheme(
    style: BackgroundStyle,
    themeMode: String, // "system" | "light" | "dark"
    content: @Composable () -> Unit,
) {
    val dark = when (themeMode) {
        "light" -> false
        "dark" -> true
        else -> isSystemInDarkTheme()
    }
    val accent = style.accent(dark)
    val scheme = if (dark) {
        darkColorScheme(
            primary = accent,
            onPrimary = Color.White,
            secondary = accent,
            surface = Color(0xE6141416),
            onSurface = Color(0xFFF2F2F4),
            surfaceVariant = Color(0xFF232326),
            onSurfaceVariant = Color(0xFFB9B9C0),
            background = Color.Transparent,
            onBackground = Color(0xFFF2F2F4),
            surfaceContainer = Color(0xCC1C1C1F),
            surfaceContainerHigh = Color(0xD9252529),
            outline = Color(0x33FFFFFF),
        )
    } else {
        lightColorScheme(
            primary = accent,
            onPrimary = Color.White,
            secondary = accent,
            surface = Color(0xE6FAFAFB),
            onSurface = Color(0xFF1B1B1E),
            surfaceVariant = Color(0xFFECECF0),
            onSurfaceVariant = Color(0xFF5B5B63),
            background = Color.Transparent,
            onBackground = Color(0xFF1B1B1E),
            surfaceContainer = Color(0xCCF2F2F5),
            surfaceContainerHigh = Color(0xD9FFFFFF),
            outline = Color(0x22000000),
        )
    }
    CompositionLocalProvider(LocalAppAccent provides accent) {
        MaterialTheme(colorScheme = scheme, typography = kiperTypography(), content = content)
    }
}
