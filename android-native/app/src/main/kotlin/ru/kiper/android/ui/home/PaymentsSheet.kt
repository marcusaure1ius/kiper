package ru.kiper.android.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import java.time.LocalDate
import java.time.YearMonth
import ru.kiper.android.KiperApp
import ru.kiper.android.data.Fmt
import ru.kiper.android.data.PaymentEvent
import ru.kiper.android.ui.components.AmountLabel
import ru.kiper.android.ui.components.SubscriptionLogo

/** Past / upcoming payments for ±90 days (mirrors `PaymentsSheet`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentsSheet(onDismiss: () -> Unit) {
    val store = KiperApp.store
    var mode by remember { mutableStateOf(Mode.FUTURE) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(horizontal = 16.dp)) {
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                SegmentedButton(
                    selected = mode == Mode.PAST,
                    onClick = { mode = Mode.PAST },
                    shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2),
                ) { Text("История") }
                SegmentedButton(
                    selected = mode == Mode.FUTURE,
                    onClick = { mode = Mode.FUTURE },
                    shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2),
                ) { Text("Предстоящие") }
            }
        }
        val events = if (mode == Mode.FUTURE) store.futurePayments() else store.pastPayments()
        val grouped = events.groupBy { YearMonth.from(it.date) }
        val months = grouped.keys.sortedWith(
            if (mode == Mode.FUTURE) compareBy { it } else compareByDescending { it }
        )
        LazyColumn(contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 32.dp)) {
            for (month in months) {
                val items = grouped[month] ?: continue
                item(key = "header-$month") {
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            Fmt.monthName(month.atDay(1)),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        Box(Modifier.weight(1f))
                        Text(
                            Fmt.rub(monthTotal(store, items)),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
                items(items.size, key = { "row-$month-${items[it].subscription.id}-${items[it].date}" }) { i ->
                    val event = items[i]
                    if (mode == Mode.FUTURE) {
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            ru.kiper.android.ui.components.SubscriptionRow(
                                subscription = event.subscription,
                                category = store.category(event.subscription.categoryId),
                                subtitle = Fmt.day(event.date),
                                toRub = store::toRub,
                            )
                        }
                    } else {
                        HistoryRow(event)
                    }
                }
            }
        }
    }
}

private enum class Mode { PAST, FUTURE }

/** Recorded amounts where they exist; skipped charges don't count. */
private fun monthTotal(store: ru.kiper.android.data.AppStore, items: List<PaymentEvent>): Double =
    items.sumOf { event ->
        val record = event.record
        if (record?.kind == ru.kiper.android.data.PaymentRecord.Kind.SKIP) 0.0
        else record?.amountRub ?: store.toRub(event.subscription.amount, event.subscription.currency)
    }

/** A past charge: the amount that actually left the account (from the record),
 * with «Оплачено / Пропустить / Удалить» actions (long-press menu on Android). */
@Composable
private fun HistoryRow(event: PaymentEvent) {
    val store = KiperApp.store
    val skipped = event.record?.kind == ru.kiper.android.data.PaymentRecord.Kind.SKIP
    var actions by remember { mutableStateOf(false) }

    Row(
        Modifier
            .fillMaxWidth()
            .clickable { actions = true }
            .padding(horizontal = 20.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SubscriptionLogo(event.subscription, store.category(event.subscription.categoryId))
        Column(Modifier.weight(1f).padding(start = 14.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                event.subscription.name,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
            )
            Text(
                if (skipped) "Пропущено" else Fmt.day(event.date),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Box(Modifier.padding(start = 8.dp)) {
            AmountLabel(
                event.record?.amount ?: event.subscription.amount,
                event.record?.currency ?: event.subscription.currency,
                store::toRub,
            )
        }
    }

    if (actions) {
        AlertDialog(
            onDismissRequest = { actions = false },
            title = { Text(event.subscription.name) },
            text = { Text(if (skipped) "Списание пропущено" else Fmt.fullDate(event.date)) },
            confirmButton = {
                if (skipped || event.record == null) {
                    TextButton(
                        onClick = {
                            store.markPaid(event.subscription, event.date)
                            actions = false
                        },
                    ) { Text("Оплачено", color = androidx.compose.ui.graphics.Color(0xFF2E7D32)) }
                }
            },
            dismissButton = {
                Column {
                    if (!skipped) {
                        TextButton(
                            onClick = {
                                store.skip(event.subscription, event.date)
                                actions = false
                            },
                        ) { Text("Пропустить", color = androidx.compose.ui.graphics.Color(0xFFEF6C00)) }
                    }
                    if (event.record != null) {
                        TextButton(
                            onClick = {
                                store.deletePayment(event.record!!.id)
                                actions = false
                            },
                        ) { Text("Удалить", color = MaterialTheme.colorScheme.error) }
                    }
                    TextButton(onClick = { actions = false }) { Text("Закрыть") }
                }
            },
        )
    }
}
