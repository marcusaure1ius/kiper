package ru.kiper.android.ui.subs

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import ru.kiper.android.KiperApp
import ru.kiper.android.data.Category
import ru.kiper.android.data.Fmt
import ru.kiper.android.data.PaymentRecord
import ru.kiper.android.data.Subscription
import ru.kiper.android.data.SubscriptionStatus
import ru.kiper.android.ui.components.AmountLabel
import ru.kiper.android.ui.components.SubscriptionLogo
import ru.kiper.android.ui.components.categoryColor
import ru.kiper.android.ui.components.categoryIcon
import ru.kiper.android.ui.theme.colorHex

/** Subscription detail: header, properties, payment history with price-change
 * badge, actions (mirrors `SubscriptionDetailScreen`). */
@Composable
fun SubscriptionDetailScreen(subscriptionId: String, onBack: () -> Unit) {
    val store = KiperApp.store
    val sub = store.subscription(subscriptionId)
    if (sub == null) {
        Column(
            Modifier.fillMaxSize().padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text("Подписка не найдена", style = MaterialTheme.typography.titleMedium)
            Button(onClick = onBack, modifier = Modifier.padding(top = 16.dp)) { Text("Назад") }
        }
        return
    }
    var editing by remember { mutableStateOf(false) }
    var confirmCancel by remember { mutableStateOf(false) }
    var menuOpen by remember { mutableStateOf(false) }

    val category = store.category(sub.categoryId)

    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 32.dp),
        ) {
            item {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Назад")
                    }
                    Box(Modifier.weight(1f))
                    TextButton(onClick = { editing = true }) { Text("Изменить") }
                    Box {
                        IconButton(onClick = { menuOpen = true }) {
                            Icon(Icons.Rounded.MoreVert, contentDescription = "Ещё")
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            if (sub.status == SubscriptionStatus.TRIAL) {
                                DropdownMenuItem(
                                    text = { Text("Завершить триал") },
                                    leadingIcon = { Icon(Icons.Rounded.PlayArrow, null) },
                                    onClick = {
                                        store.endTrial(sub.id)
                                        store.show("Триал завершён — подписка активна")
                                        menuOpen = false
                                    },
                                )
                            } else {
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            if (sub.status == SubscriptionStatus.PAUSED) "Возобновить"
                                            else "Приостановить"
                                        )
                                    },
                                    leadingIcon = {
                                        Icon(
                                            if (sub.status == SubscriptionStatus.PAUSED) Icons.Rounded.PlayArrow
                                            else Icons.Rounded.Pause,
                                            null,
                                        )
                                    },
                                    onClick = {
                                        val wasPaused = sub.status == SubscriptionStatus.PAUSED
                                        store.togglePause(sub.id)
                                        store.show(if (wasPaused) "Подписка возобновлена" else "Подписка на паузе")
                                        menuOpen = false
                                    },
                                )
                            }
                            DropdownMenuItem(
                                text = { Text("Отменить подписку", color = MaterialTheme.colorScheme.error) },
                                onClick = {
                                    confirmCancel = true
                                    menuOpen = false
                                },
                            )
                        }
                    }
                }
            }

            item {
                Column(
                    Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    SubscriptionLogo(sub, category, size = 84.dp)
                    Text(sub.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    AmountLabel(sub.amount, sub.currency, store::toRub)
                    if (category != null) CategoryTag(category)
                }
            }

            item {
                Column(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
                        .clip(RoundedCornerShape(22.dp))
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                ) {
                    InfoRow(
                        "Период",
                        if (sub.billingPeriod == ru.kiper.android.data.BillingPeriod.CUSTOM)
                            "Каждые ${sub.customPeriodDays ?: 30} дн."
                        else sub.billingPeriod.label,
                    )
                    InfoRow(
                        if (sub.status == SubscriptionStatus.TRIAL) "Первое списание" else "Следующее списание",
                        "${Fmt.fullDate(sub.nextBillingDate)} · ${Fmt.relative(sub.nextBillingDate).lowercase()}",
                    )
                    if (sub.status == SubscriptionStatus.TRIAL && sub.trialEndDate != null) {
                        InfoRow("Триал до", "${Fmt.fullDate(sub.trialEndDate!!)} · ${Fmt.relative(sub.trialEndDate!!).lowercase()}")
                    }
                    InfoRow("Дата начала", Fmt.fullDate(sub.startDate))
                    InfoRow("Статус", sub.status.label)
                    InfoRow("Напоминание", if (sub.reminderDaysBefore == 0) "Выключено" else "За ${sub.reminderDaysBefore} дн.")
                    if (sub.status != SubscriptionStatus.TRIAL) {
                        InfoRow("В месяц", Fmt.rub(store.toRub(sub.amount, sub.currency) * sub.billingPeriod.monthlyEquivalent))
                    }
                }
            }

            if (sub.status != SubscriptionStatus.TRIAL) {
                val history = store.payments
                    .filter { it.subscriptionId == sub.id && it.kind == PaymentRecord.Kind.CHARGE }
                    .sortedByDescending { it.date }
                if (history.isNotEmpty()) {
                    item {
                        Column(
                            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
                                .clip(RoundedCornerShape(22.dp))
                                .background(MaterialTheme.colorScheme.surface)
                                .padding(horizontal = 16.dp, vertical = 6.dp),
                        ) {
                            Text(
                                "История платежей",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(vertical = 8.dp),
                            )
                            val last = history.first()
                            if (last.amount != sub.amount || last.currency != sub.currency) {
                                InfoRow("Цена изменилась", null)
                                Text(
                                    "${Fmt.money(last.amount, last.currency)} → ${Fmt.money(sub.amount, sub.currency)}",
                                    color = Color(0xFFEF6C00),
                                    modifier = Modifier.padding(bottom = 6.dp),
                                )
                            }
                            for (record in history.take(5)) {
                                InfoRow(Fmt.smartDate(record.date), Fmt.money(record.amount, record.currency))
                            }
                        }
                    }
                }
            }

            if (!sub.note.isNullOrEmpty()) {
                item {
                    Column(
                        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
                            .clip(RoundedCornerShape(22.dp))
                            .background(MaterialTheme.colorScheme.surface)
                            .padding(16.dp),
                    ) {
                        Text(
                            "Заметка",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(sub.note!!, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 6.dp))
                    }
                }
            }
        }
    }

    if (editing) {
        SubscriptionFormSheet(editing = sub, onDismiss = { editing = false })
    }

    if (confirmCancel) {
        AlertDialog(
            onDismissRequest = { confirmCancel = false },
            title = { Text("Отменить «${sub.name}»?") },
            text = { Text("Подписка останется в аналитике, но исчезнет из списка.") },
            confirmButton = {
                TextButton(onClick = {
                    store.cancel(sub.id)
                    store.show("Подписка отменена")
                    confirmCancel = false
                    onBack()
                }) { Text("Отменить подписку", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { confirmCancel = false }) { Text("Закрыть") }
            },
        )
    }
}

@Composable
private fun InfoRow(title: String, value: String?) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Box(Modifier.weight(1f))
        if (value != null) {
            Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
        }
    }
}

/** Flat tinted tag (system-style): icon and text in the category colour. */
@Composable
private fun CategoryTag(category: Category) {
    val tint = colorHex(category.colorHex)
    Row(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(tint.copy(alpha = 0.16f))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Icon(categoryIcon(category.symbol), null, tint = tint, modifier = Modifier.size(14.dp))
        Text(category.name, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, color = tint)
    }
}
