package ru.kiper.android.ui.theme

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlin.math.sin

/**
 * Soft colourful backdrop so the translucent surfaces have something to show.
 * Palette is picked in Settings; the mesh slowly flows (Apple Music style):
 * three drifting radial blobs over the palette base, heavily blurred.
 * Honours the system "remove animations" setting.
 */
@Composable
fun FlowingBackdrop(style: BackgroundStyle, modifier: Modifier = Modifier) {
    val dark = isSystemInDarkTheme()
    val colors = style.colors(dark).map { colorHex(it) }
    val base = colors[4]
    val blobs = listOf(colors[0], colors[5], colors[2])

    val reduceMotion = reduceMotionEnabled()
    val t by produceState(0.0, reduceMotion) {
        if (reduceMotion) {
            value = 0.0
        } else {
            val start = withFrameNanos { it }
            while (true) {
                withFrameNanos { frame -> value = (frame - start) / 1_000_000_000.0 }
            }
        }
    }

    Box(modifier.fillMaxSize().blur(40.dp).scale(1.35f)) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(base)
            fun w(speed: Double, phase: Double, amp: Float) = (sin(t * speed + phase) * amp).toFloat()
            fun blob(color: Color, cx: Float, cy: Float, radius: Float) {
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(color, color.copy(alpha = 0f)),
                        center = Offset(cx * size.width, cy * size.height),
                        radius = radius * size.width,
                    ),
                    center = Offset(cx * size.width, cy * size.height),
                    radius = radius * size.width,
                )
            }
            blob(blobs[0], 0.20f + w(0.31, 0.0, 0.10f), 0.15f + w(0.23, 1.1, 0.08f), 0.65f)
            blob(blobs[1], 0.85f + w(0.27, 2.1, 0.10f), 0.45f + w(0.19, 0.4, 0.10f), 0.60f)
            blob(blobs[2], 0.45f + w(0.22, 4.2, 0.12f), 0.90f + w(0.29, 3.3, 0.08f), 0.65f)
        }
    }
}

@Composable
private fun reduceMotionEnabled(): Boolean {
    val context = LocalContext.current
    return remember {
        try {
            android.provider.Settings.Global.getFloat(
                context.contentResolver,
                android.provider.Settings.Global.ANIMATOR_DURATION_SCALE, 1f,
            ) == 0f
        } catch (_: Exception) {
            false
        }
    }
}

/** Small static palette preview (Settings row). */
@Composable
fun MeshBackdropPreview(style: BackgroundStyle, modifier: Modifier = Modifier) {
    val dark = isSystemInDarkTheme()
    val colors = style.colors(dark).map { colorHex(it) }
    Box(modifier.blur(8.dp)) {
        Row(Modifier.fillMaxSize()) {
            colors.take(6).forEach { c ->
                Box(Modifier.weight(1f).fillMaxSize()) {
                    Canvas(Modifier.fillMaxSize()) { drawRect(c) }
                }
            }
        }
    }
}
