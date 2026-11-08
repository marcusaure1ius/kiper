package ru.kiper.android.ui.home

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Checklist
import androidx.compose.material.icons.rounded.EventRepeat
import androidx.compose.material.icons.rounded.FormatListBulleted
import androidx.compose.material.icons.rounded.Inbox
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Adjust
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.clickable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ru.kiper.android.KiperApp
import ru.kiper.android.data.Fmt
import ru.kiper.android.ui.components.Card
import ru.kiper.android.ui.components.SubscriptionRow
import java.time.LocalDate

/** Home tab — hero month card, action buttons, upcoming charges. */
@Composable
fun HomeScreen(
    onOpenList: () -> Unit,
    onOpenDetail: (String) -> Unit,
    onAdd: () -> Unit,
    onOpenPayments: () -> Unit,
) {
    val store = KiperApp.store
    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 20.dp, end = 20.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            item {
                Column(Modifier.padding(top = 18.dp)) {
                    MonthSummaryCard()
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    FilledTonalButton(
                        onClick = onOpenList,
                        modifier = Modifier.weight(1f).height(54.dp).border(
                            1.dp,
                            MaterialTheme.colorScheme.outline.copy(alpha = 0.35f),
                            androidx.compose.foundation.shape.RoundedCornerShape(27.dp),
                        ),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(27.dp),
                        colors = ButtonDefaults.filledTonalButtonColors(
                            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                        ),
                    ) {
                        Icon(Icons.Rounded.FormatListBulleted, null, Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Подписки", fontWeight = FontWeight.SemiBold)
                    }
                    Button(
                        onClick = onAdd,
                        modifier = Modifier.weight(1f).height(54.dp),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(27.dp),
                    ) {
                        Icon(Icons.Rounded.Add, null, Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Добавить", fontWeight = FontWeight.SemiBold)
                    }
                }
            }
            item { UpcomingCard(onOpenPayments, onOpenDetail, onAdd) }
        }
    }
}

/** Glass summary for the current month — the hero element of the home screen. */
@Composable
fun MonthSummaryCard() {
    val store = KiperApp.store
    val accent = MaterialTheme.colorScheme.primary
    val progress = store.monthProgress()
    val total = progress.first + progress.second
    val budget = store.monthlyBudgetRub
    val overBudget = budget?.let { total > it } ?: false
    val fraction = if (budget != null) {
        (total / maxOf(budget, 1.0)).coerceAtMost(1.0)
    } else {
        if (total > 0) progress.first / total else 0.0
    }

    // Count-up animation for the hero number.
    var started by remember { mutableStateOf(false) }
    LaunchedEffect(store.monthlyTotalRub) { started = true }
    val animated by animateFloatAsState(
        targetValue = store.monthlyTotalRub.toFloat(),
        animationSpec = tween(durationMillis = 700),
        label = "countUp",
    )

    val cardShape = androidx.compose.foundation.shape.RoundedCornerShape(32.dp)
    val barColor = if (overBudget) Color(0xFFF57C00) else accent
    Column(
        Modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(
                androidx.compose.ui.graphics.Brush.verticalGradient(
                    listOf(accent.copy(alpha = 0.32f), MaterialTheme.colorScheme.surfaceContainerHigh)
                )
            )
            .border(1.dp, Color.White.copy(alpha = 0.45f), cardShape)
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            Fmt.monthName(LocalDate.now()),
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            Fmt.rub(animated.toDouble()),
            style = ru.kiper.android.ui.theme.HeroNumberStyle,
            color = MaterialTheme.colorScheme.onSurface,
        )
        // Rounded custom bar — Material's default draws a stray dot at the end.
        androidx.compose.foundation.Canvas(
            Modifier.fillMaxWidth().height(10.dp).clip(androidx.compose.foundation.shape.RoundedCornerShape(5.dp)),
        ) {
            drawRoundRect(
                color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.55f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(size.height / 2, size.height / 2),
            )
            if (fraction > 0.001f) {
                drawRoundRect(
                    color = barColor,
                    size = androidx.compose.ui.geometry.Size(size.width * fraction.toFloat(), size.height),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(size.height / 2, size.height / 2),
                )
            }
        }
        Row(Modifier.fillMaxWidth()) {
            Stat("Оплачено", progress.first, Icons.Rounded.CheckCircle)
            Spacer(Modifier.weight(1f))
            Stat("Осталось", progress.second, Icons.Rounded.Schedule)
        }
        if (budget != null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    if (overBudget) Icons.Rounded.Warning else Icons.Rounded.Adjust,
                    null,
                    tint = barColor,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    "Бюджет · ${Fmt.rub(budget)}",
                    style = MaterialTheme.typography.labelMedium,
                    color = if (overBudget) barColor else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.weight(1f))
                if (overBudget) {
                    Text(
                        "перерасход ${Fmt.rub(total - budget)}",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = barColor,
                    )
                }
            }
        }
    }
}

@Composable
private fun Stat(title: String, value: Double, icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(8.dp))
        Column {
            Text(title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(
                Fmt.rub(value),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

/** «Ближайшие списания» — the next 30 days, six rows, like the iOS card. */
@Composable
private fun UpcomingCard(onOpenPayments: () -> Unit, onOpenDetail: (String) -> Unit, onAdd: () -> Unit) {
    val store = KiperApp.store
    Card {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 8.dp)) {
            Text("Ближайшие списания", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            TextButton(onClick = onOpenPayments) {
                Text("Все", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            }
        }
        val events = store.futurePayments(days = 30).take(6)
        if (events.isEmpty()) {
            // Trials count as subscriptions here too — a lone trial with a far-away
            // first charge is still "нет списаний", not "нет подписок".
            val empty = store.notCancelled.isEmpty()
            Column(
                Modifier.fillMaxWidth().padding(vertical = 18.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(
                    if (empty) Icons.Rounded.Inbox else Icons.Rounded.EventRepeat,
                    null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(34.dp),
                )
                Text(
                    if (empty) "Пока нет подписок" else "В ближайший месяц списаний нет",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                if (empty) {
                    Text(
                        "Добавьте первую — Кипер напомнит о списании заранее.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                    Button(onClick = onAdd) {
                        Icon(Icons.Rounded.Add, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Добавить подписку")
                    }
                }
            }
        }
        events.forEachIndexed { index, event ->
            Box(Modifier.fillMaxWidth().padding(vertical = 8.dp).clickable { onOpenDetail(event.subscription.id) }) {
                SubscriptionRow(
                    subscription = event.subscription,
                    category = store.category(event.subscription.categoryId),
                    subtitle = "${Fmt.relative(event.date)} · ${Fmt.day(event.date)}",
                    toRub = store::toRub,
                )
            }
            if (index != events.lastIndex) {
                HorizontalDivider(
                    Modifier.padding(start = 60.dp),
                    color = MaterialTheme.colorScheme.outline.copy(alpha = 0.25f),
                )
            }
        }
    }
}
