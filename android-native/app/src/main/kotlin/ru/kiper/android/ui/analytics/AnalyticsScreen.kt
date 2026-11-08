package ru.kiper.android.ui.analytics

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ru.kiper.android.KiperApp
import ru.kiper.android.data.Fmt
import ru.kiper.android.data.PeriodTotal
import ru.kiper.android.ui.components.Card
import ru.kiper.android.ui.components.SubscriptionRow
import ru.kiper.android.ui.theme.colorHex
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.TemporalAdjusters

/** Analytics tab: bar chart, category rings, month-over-month, annual cost,
 * duplicates (mirrors `AnalyticsScreen`). */
@Composable
fun AnalyticsScreen() {
    val store = KiperApp.store
    var period by remember { mutableStateOf(ChartPeriod.MONTH) }

    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                "Аналитика",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 18.dp, bottom = 2.dp),
            )
            SpendingChartCard(period, onPeriodChange = { period = it })
            CategoryRingsCard(period)
            MonthOverMonthCard()
            AnnualCostCard()
            DuplicatesCard()
            Spacer(Modifier.height(8.dp))
        }
    }
}

private enum class ChartPeriod(val title: String) { MONTH("Месяц"), WEEK("Неделя") }

private fun periodStart(date: LocalDate, period: ChartPeriod): LocalDate = when (period) {
    ChartPeriod.MONTH -> YearMonth.from(date).atDay(1)
    ChartPeriod.WEEK -> date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
}

private fun periodEnd(date: LocalDate, period: ChartPeriod): LocalDate = when (period) {
    ChartPeriod.MONTH -> YearMonth.from(date).atEndOfMonth().plusDays(1)
    ChartPeriod.WEEK -> date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)).plusWeeks(1)
}

/** Same-span month comparison: "now vs last month up to the same day". */
@Composable
private fun MonthOverMonthCard() {
    val store = KiperApp.store
    val delta = store.monthOverMonth() ?: return
    Card {
        Text("Месяц к месяцу", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 6.dp)) {
            Icon(
                if (delta.delta > 0) Icons.Rounded.ArrowUpward else Icons.Rounded.ArrowDownward,
                null,
                tint = if (delta.delta > 0) Color(0xFFEF6C00) else Color(0xFF2E7D32),
                modifier = Modifier.size(24.dp),
            )
            Spacer(Modifier.size(8.dp))
            Text(
                Fmt.rub(kotlin.math.abs(delta.delta)),
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        Text(
            "${Fmt.rub(delta.current)} списано сейчас против ${Fmt.rub(delta.previous)} в прошлом месяце к этому дню",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

/** Steady-state year cost with the top-3 contributors. */
@Composable
private fun AnnualCostCard() {
    val store = KiperApp.store
    val (totalRub, top) = store.annualForecast()
    if (totalRub <= 0) return
    Card {
        Text("Годовая стоимость", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(
            Fmt.rub(totalRub),
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 6.dp),
        )
        Text(
            "если ничего не менять",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 6.dp),
        )
        top.forEachIndexed { i, item ->
            SubscriptionRow(
                subscription = item.subscription,
                category = store.category(item.subscription.categoryId),
                subtitle = "${Fmt.rub(item.perYearRub)} в год",
                toRub = store::toRub,
            )
            if (i != top.lastIndex) {
                HorizontalDivider(Modifier.padding(start = 58.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.25f))
            }
        }
    }
}

/** Likely duplicates: same domain or a similar name in one category. */
@Composable
private fun DuplicatesCard() {
    val store = KiperApp.store
    val groups = store.duplicateGroups()
    if (groups.isEmpty()) return
    Card {
        Text("Похожие подписки", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(
            "Похоже на дубликаты — проверьте, нужны ли обе",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 6.dp),
        )
        for (group in groups) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                    .padding(10.dp)
                    .padding(bottom = 0.dp),
            ) {
                for (sub in group) {
                    SubscriptionRow(
                        subscription = sub,
                        category = store.category(sub.categoryId),
                        subtitle = sub.billingPeriod.label,
                        toRub = store::toRub,
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

/** Bar chart of spending; tapping a bar selects that month/week for the rings below. */
@Composable
private fun SpendingChartCard(period: ChartPeriod, onPeriodChange: (ChartPeriod) -> Unit) {
    val store = KiperApp.store
    var selection by remember(period) { mutableStateOf(periodStart(LocalDate.now(), period)) }
    val data = if (period == ChartPeriod.MONTH) store.monthlyTotals() else store.weeklyTotals()
    val selected = data.firstOrNull { it.start == selection }
    val accent = MaterialTheme.colorScheme.primary

    Card {
        Text(
            if (period == ChartPeriod.MONTH) "Расходы по месяцам" else "Расходы по неделям",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        if (selected != null) {
            Text(
                Fmt.rub(selected.amount),
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 6.dp),
            )
            Text(
                caption(period, selected),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.height(12.dp))

        val maxAmount = data.maxOfOrNull { it.amount }?.takeIf { it > 0 } ?: 1.0
        Box(Modifier.fillMaxWidth().height(200.dp)) {
            Canvas(Modifier.fillMaxSize()) {
                val n = data.size
                val slot = size.width / n
                val barWidth = slot * 0.55f
                data.forEachIndexed { i, item ->
                    val h = (item.amount / maxAmount).toFloat() * (size.height * 0.92f)
                    val color = if (item.start == selection) accent
                    else accent.copy(alpha = if (item.isForecast) 0.22f else 0.5f)
                    drawRoundRect(
                        color = color,
                        topLeft = Offset(i * slot + (slot - barWidth) / 2, size.height - h),
                        size = androidx.compose.ui.geometry.Size(barWidth, h),
                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(12f, 12f),
                    )
                }
            }
            // Tap-to-select: invisible row of equal slots over the bars.
            Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.SpaceBetween) {
                data.forEach { item ->
                    Box(
                        Modifier.weight(1f).fillMaxSize().clickable {
                            selection = item.start
                        },
                    )
                }
            }
        }
        // Labels row under the bars (simplified x-axis).
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            data.forEachIndexed { i, item ->
                if (period == ChartPeriod.MONTH || i % 2 == 0) {
                    Text(
                        if (period == ChartPeriod.MONTH) Fmt.monthShort(item.start)
                        else "${item.start.dayOfMonth}.${item.start.monthValue}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.weight(1f),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                } else {
                    Spacer(Modifier.weight(1f))
                }
            }
        }

        if (data.all { it.amount == 0.0 }) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 8.dp)) {
                Icon(Icons.Rounded.BarChart, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(6.dp))
                Text("Пока нет списаний", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(top = 14.dp)) {
            SegmentedButton(
                selected = period == ChartPeriod.MONTH,
                onClick = { onPeriodChange(ChartPeriod.MONTH) },
                shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2),
            ) { Text("Месяц") }
            SegmentedButton(
                selected = period == ChartPeriod.WEEK,
                onClick = { onPeriodChange(ChartPeriod.WEEK) },
                shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2),
            ) { Text("Неделя") }
        }
    }
}

private fun caption(period: ChartPeriod, point: PeriodTotal): String {
    val label = if (period == ChartPeriod.MONTH) Fmt.monthName(point.start) else "Неделя с ${Fmt.day(point.start)}"
    if (periodStart(LocalDate.now(), period) == point.start) return "$label · сейчас"
    return if (point.isForecast) "$label · прогноз" else label
}

/** Categories for the selected period. Current period: share already paid. */
@Composable
private fun CategoryRingsCard(period: ChartPeriod) {
    val store = KiperApp.store
    val start = periodStart(LocalDate.now(), period)
    val end = periodEnd(LocalDate.now(), period)
    val rows = store.categoryShares(start, end)
    val total = rows.sumOf { it.total }
    val isCurrent = start == periodStart(LocalDate.now(), period)

    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("По категориям", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            Text(
                subtitle(period, start, isCurrent),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (rows.isEmpty()) {
            Text(
                "Списаний нет",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = 8.dp),
            )
        }
        rows.forEachIndexed { i, row ->
            val color = row.category?.let { colorHex(it.colorHex) } ?: Color.Gray
            val fraction = if (isCurrent) row.paid / maxOf(row.total, 1.0) else row.total / maxOf(total, 1.0)
            Row(
                Modifier.fillMaxWidth().padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Ring(progress = fraction, color = color, modifier = Modifier.size(28.dp))
                Spacer(Modifier.size(12.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        row.category?.name ?: "Без категории",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                    )
                    Text(
                        if (isCurrent) "${Fmt.rub(row.paid)} из ${Fmt.rub(row.total)}" else Fmt.rub(row.total),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    "${Math.round(fraction * 100)}%",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = color,
                )
            }
            if (i != rows.lastIndex) {
                HorizontalDivider(Modifier.padding(start = 40.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.25f))
            }
        }
    }
}

@Composable
private fun Ring(progress: Double, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = Stroke(width = 10f, cap = StrokeCap.Round)
        drawArc(
            color = color.copy(alpha = 0.18f),
            startAngle = 0f, sweepAngle = 360f, useCenter = false,
            style = stroke,
        )
        drawArc(
            color = color,
            startAngle = -90f, sweepAngle = (360f * maxOf(progress, 0.001)).toFloat(), useCenter = false,
            style = stroke,
        )
    }
}

private fun subtitle(period: ChartPeriod, start: LocalDate, isCurrent: Boolean): String {
    val name = if (period == ChartPeriod.MONTH) "в ${Fmt.monthPrepositional(start)}" else "за неделю с ${Fmt.day(start)}"
    if (isCurrent) return if (period == ChartPeriod.MONTH) "оплачено $name" else "оплачено за эту неделю"
    return if (start > LocalDate.now()) "прогноз $name" else "доля трат $name"
}
