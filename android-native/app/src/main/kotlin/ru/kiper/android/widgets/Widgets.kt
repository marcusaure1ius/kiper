package ru.kiper.android.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.Action
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import ru.kiper.android.MainActivity
import ru.kiper.android.data.Fmt
import ru.kiper.android.data.WidgetSnapshot
import java.io.File
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/** Shared plumbing: snapshot file in the app's own storage + palette accent. */
object WidgetData {
    fun snapshot(context: Context): WidgetSnapshot? = WidgetSnapshot.load(context.filesDir)

    fun accent(context: Context, dark: Boolean): Color {
        val snapshot = snapshot(context)
        val hex = if (dark) snapshot?.accentHexDark ?: 0x8F84FF else snapshot?.accentHexLight ?: 0x6A5CF1
        return Color(0xFF000000L or (hex.toLong() and 0xFFFFFF))
    }

    /** Asks the launcher to redraw every Kiper widget (called after each save). */
    fun refresh(context: Context) {
        CoroutineScope(Dispatchers.Default).launch {
            try {
                NextChargeWidget.updateAll(context)
                MonthWidget.updateAll(context)
            } catch (_: Exception) {
            }
        }
    }
}

/** Relative day label matching the app («Сегодня/Завтра/Через N дн.»). */
internal fun relativeDay(date: LocalDate, today: LocalDate = LocalDate.now()): String {
    val days = ChronoUnit.DAYS.between(today, date).toInt()
    return when {
        days <= 0 -> "Сегодня"
        days == 1 -> "Завтра"
        else -> "Через $days дн."
    }
}

private val openApp: Action get() = actionStartActivity(MainActivity::class.java)

/** «Ближайшее списание» widget (small/medium). */
object NextChargeWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = WidgetData.snapshot(context)
        provideContent {
            val accent = ColorProvider(WidgetData.accent(context, dark = false))
            val onSurface = GlanceTheme.colors.onSurface
            val muted = ColorProvider(onSurface.getColor(context).copy(alpha = 0.62f))
            GlanceTheme {
                Box(
                    GlanceModifier.fillMaxSize()
                        .background(GlanceTheme.colors.surface)
                        .clickable(openApp)
                        .padding(14.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    Column {
                        Text(
                            "Ближайшее списание",
                            style = TextStyle(color = muted, fontSize = 11.sp),
                        )
                        Spacer(GlanceModifier.height(6.dp))
                        val first = snapshot?.upcoming?.firstOrNull()
                        if (first == null) {
                            Text(
                                "Списаний нет",
                                style = TextStyle(color = onSurface, fontSize = 17.sp, fontWeight = FontWeight.Bold),
                            )
                        } else {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    Fmt.money(first.amount, ru.kiper.android.data.Currency.of(first.currency)),
                                    style = TextStyle(color = accent, fontSize = 19.sp, fontWeight = FontWeight.Bold),
                                )
                                Spacer(GlanceModifier.width(8.dp))
                                Text(
                                    first.name,
                                    style = TextStyle(color = onSurface, fontSize = 13.sp),
                                    maxLines = 1,
                                )
                            }
                            Spacer(GlanceModifier.height(2.dp))
                            Text(
                                "${relativeDay(first.localDate)} · ${Fmt.day(first.localDate)}",
                                style = TextStyle(color = muted, fontSize = 12.sp),
                            )
                            val second = snapshot.upcoming.getOrNull(1)
                            if (second != null) {
                                Spacer(GlanceModifier.height(8.dp))
                                Text(
                                    "Далее: ${second.name} · ${Fmt.day(second.localDate)}",
                                    style = TextStyle(color = muted, fontSize = 11.sp),
                                    maxLines = 1,
                                )
                            }
                        }
                        Spacer(GlanceModifier.height(8.dp))
                        Text(
                            "В месяц ≈ ${Fmt.rub(snapshot?.monthlyTotalRub ?: 0.0)}",
                            style = TextStyle(color = muted, fontSize = 12.sp),
                        )
                    }
                }
            }
        }
    }
}

class NextChargeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NextChargeWidget
}

/** «Месяц» widget: month total, budget progress, paid/remaining. */
object MonthWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = WidgetData.snapshot(context)
        provideContent {
            val onSurface = GlanceTheme.colors.onSurface
            val muted = ColorProvider(onSurface.getColor(context).copy(alpha = 0.62f))
            GlanceTheme {
                Box(
                    GlanceModifier.fillMaxSize()
                        .background(GlanceTheme.colors.surface)
                        .clickable(openApp)
                        .padding(14.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Column {
                        Text(
                            Fmt.monthName(LocalDate.now()),
                            style = TextStyle(color = muted, fontSize = 12.sp),
                        )
                        Spacer(GlanceModifier.height(4.dp))
                        if (snapshot == null) {
                            Text(
                                "Нет данных",
                                style = TextStyle(color = onSurface, fontSize = 17.sp, fontWeight = FontWeight.Bold),
                            )
                        } else {
                            Text(
                                Fmt.rub(snapshot.monthlyTotalRub),
                                style = TextStyle(color = onSurface, fontSize = 22.sp, fontWeight = FontWeight.Bold),
                            )
                            Spacer(GlanceModifier.height(10.dp))
                            // Budget progress bar (orange over budget), or paid-of-total
                            // when no budget is set — same rule as the home card.
                            val total = snapshot.paidRub + snapshot.remainingRub
                            val over = snapshot.budgetRub?.let { total > it } ?: false
                            val fraction = if (snapshot.budgetRub != null && snapshot.budgetRub > 0) {
                                (total / snapshot.budgetRub).coerceAtMost(1.0)
                            } else if (total > 0) {
                                snapshot.paidRub / total
                            } else 0.0
                            val barColor = if (over) Color(0xFFFF9800) else WidgetData.accent(context, dark = false)
                            LinearProgressIndicator(
                                progress = fraction.toFloat(),
                                modifier = GlanceModifier.fillMaxWidth().height(6.dp),
                                color = ColorProvider(barColor),
                                backgroundColor = GlanceTheme.colors.secondaryContainer,
                            )
                            Spacer(GlanceModifier.height(6.dp))
                            Text(
                                "Оплачено ${Fmt.rub(snapshot.paidRub)} · Осталось ${Fmt.rub(snapshot.remainingRub)}",
                                style = TextStyle(color = muted, fontSize = 11.sp),
                                maxLines = 1,
                            )
                        }
                    }
                }
            }
        }
    }
}

class MonthWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MonthWidget
}
